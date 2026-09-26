import Foundation
import SwiftData

/// Network orchestration only. Local study transitions never await this service.
@MainActor
final class StudyProgressSync {
    static let shared = StudyProgressSync()
    private let api: StudyProgressAPI
    private let accounts: LocalAccountStore
    private let refresh: () async throws -> Void
    private var flushing = Set<UUID>()

    init(api: StudyProgressAPI? = nil, accounts: LocalAccountStore? = nil,
         refresh: @escaping () async throws -> Void = { _ = try await AuthAPI.shared.refreshAccessToken() }) {
        self.api = api ?? .shared
        self.accounts = accounts ?? .shared
        self.refresh = refresh
    }

    /// Short best-effort GET before capture. Resumes (including unknown legacy
    /// bindings) never acquire a different learning cycle. Offline uses the cache.
    func prepare(_ study: StudySession, context: ModelContext) async {
        guard !study.wasResuming, !study.isStarted,
              let session = try? accounts.session(),
              let store = try? StudyProgressStore(modelContext: context, accounts: accounts) else { return }
        let deckIDs = Set(study.decks.map(\.id))
        let parents = Set(study.decks.compactMap { $0.parentDeck?.id })
        let scopes: [UUID]
        if study.isCombined, parents.count == 1, let parent = parents.first,
           study.decks.allSatisfy({ $0.parentDeck?.id == parent }) {
            scopes = [parent]
        } else {
            scopes = deckIDs.sorted { $0.uuidString < $1.uuidString }
        }
        // Study All normally uses one parent GET. A total preparation budget
        // prevents unrelated scopes from multiplying the wait when offline.
        let deadline = Date().addingTimeInterval(3)
        for scope in scopes {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0, !Task.isCancelled else { return }
            do {
                let fetchedAt = Date()
                let snapshot = try await api.get(deckID: scope, timeout: remaining)
                try accounts.validate(session)
                try Task.checkCancellation()
                guard snapshot.deckID == scope else { throw APIError.invalidResponse }
                for deck in snapshot.decks where deckIDs.contains(deck.deckID) {
                    try store.cacheEpoch(deck.progressEpoch, for: deck.deckID, fetchedAt: fetchedAt)
                }
            } catch {
                // No refresh wait at this UI boundary. Upload will use the normal
                // auth refresh path; study remains available with cached/nil epochs.
                Self.log("epoch preparation deferred")
                return
            }
        }
    }

    /// Every trigger first seals local work, even if another trigger owns the
    /// pipeline. The owner drains newly sealed work once; failures wait for a
    /// future trigger. No timer, per-card request or unbounded retry loop.
    func flush(context: ModelContext) async {
        guard let owner = accounts.ownerID, let session = try? accounts.session(),
              let store = try? StudyProgressStore(modelContext: context, accounts: accounts) else { return }
        do { try store.sealDrafts() }
        catch { Self.log("sealing deferred"); return }
        guard flushing.insert(owner).inserted else { return }
        defer { flushing.remove(owner) }
        var attempted = Set<UUID>()
        do {
            while true {
                try accounts.validate(session)
                try Task.checkCancellation()
                let pending = try store.pending().sorted {
                    ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt)
                }
                guard let item = pending.first(where: {
                    !attempted.contains($0.id) && ($0.state == .sealed || $0.state == .reconciliationRequired)
                }) else { return }
                attempted.insert(item.id)
                if item.state == .reconciliationRequired {
                    try await reconcile(item, store: store, session: session)
                    continue
                }
                if try item.events.contains(where: {
                    try store.creditIsBlocked(deckID: $0.deckID, epoch: $0.progressEpoch, cardID: $0.cardID)
                }) {
                    try store.block(batchID: item.id, code: "blocked_by_rejected_learning", reconcile: false)
                    continue
                }
                let upload = try store.sealedUpload(batchID: item.id)
                Self.log("upload started operation_id=\(upload.operationID)")
                do {
                    let receipt = try await authenticated(session: session) {
                        try await self.api.submit(payload: upload.payload)
                    }
                    try accounts.validate(session)
                    try Self.validate(receipt, upload: upload)
                    try store.acknowledge(upload)
                    Self.log("upload acknowledged operation_id=\(upload.operationID)")
                } catch {
                    try accounts.validate(session)
                    let apiError = error as? APIError
                    let status = apiError?.statusCode
                    let code = apiError?.businessCode ?? status.map { "http_\($0)" } ?? "response_or_transport"
                    if code == "stale_progress_epoch" || code == "card_not_in_deck" {
                        // Persist the stop marker BEFORE any reconciliation await.
                        try store.block(batchID: item.id, code: code, reconcile: true)
                        Self.log("reconciliation operation_id=\(upload.operationID) code=\(code)")
                        try await reconcile(try store.pending(batchID: item.id), store: store, session: session)
                    } else if let status, (400..<500).contains(status), ![401, 408, 425, 429].contains(status) {
                        try store.block(batchID: item.id, code: code, reconcile: false)
                        Self.log("terminal operation_id=\(upload.operationID) code=\(code)")
                    } else {
                        Self.log("deferred operation_id=\(upload.operationID) reason=\(code)")
                        return
                    }
                }
            }
        } catch {
            Self.log("flush deferred")
        }
    }

    private func authenticated<T>(session: UUID, operation: () async throws -> T) async throws -> T {
        try accounts.validate(session)
        do { return try await operation() }
        catch {
            try accounts.validate(session)
            guard (error as? APIError)?.statusCode == 401 else { throw error }
            // At most one refresh and one resend, with the original raw body.
            // Refresh errors never become terminal progress errors (even a 400).
            do { try await refresh() }
            catch { throw APIError.networkError(error) }
            try accounts.validate(session)
            return try await operation()
        }
    }

    private func reconcile(_ item: PendingStudyProgressSnapshot, store: StudyProgressStore, session: UUID) async throws {
        for id in Set(item.events.map(\.deckID)).sorted(by: { $0.uuidString < $1.uuidString }) {
            let fetchedAt = Date()
            do {
                let snapshot = try await authenticated(session: session) { try await self.api.get(deckID: id) }
                try accounts.validate(session)
                guard snapshot.deckID == id else { throw APIError.invalidResponse }
                // This read also obtains current card membership for missing-card
                // reconciliation. Never delete/replace an active local queue here.
                for deck in snapshot.decks {
                    do { try store.cacheEpoch(deck.progressEpoch, for: deck.deckID, fetchedAt: fetchedAt) }
                    catch StudyProgressStorageError.deckUnavailable { /* Cache may already be gone. */ }
                }
            } catch {
                try accounts.validate(session)
                // A deleted deck is also a definitive reconciliation result.
                guard (error as? APIError)?.statusCode == 404 else { throw error }
            }
        }
        try store.block(batchID: item.id, code: item.failureCode ?? "reconciled", reconcile: false)
    }

    static func validate(_ receipt: StudyProgressSubmissionResponse, upload: SealedStudyProgressUpload) throws {
        // Decode solely for validation. The outgoing body always remains raw Data.
        let request = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: upload.payload)
        guard receipt.sessionID == upload.operationID, request.sessionID == upload.operationID,
              receipt.completedAt == upload.completedAt,
              receipt.decks.count == request.decks.count,
              Set(receipt.decks.map(\.deckID)).count == receipt.decks.count else { throw APIError.invalidResponse }
        for group in request.decks {
            guard let result = receipt.decks.first(where: { $0.deckID == group.deckID }),
                  result.progressEpoch == group.progressEpoch else { throw APIError.invalidResponse }
            let acknowledged = result.acceptedCardIDs + result.alreadyLearnedCardIDs
            guard Set(acknowledged).count == acknowledged.count,
                  Set(acknowledged) == Set(group.learnedCards.map(\.cardID)) else { throw APIError.invalidResponse }
        }
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("STUDY PROGRESS \(message)")
        #endif
    }
}
