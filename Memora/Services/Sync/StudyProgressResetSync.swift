import Foundation
import SwiftData

@MainActor
final class StudyProgressResetSync {
    static let shared = StudyProgressResetSync()
    private let progress: StudyProgressSync
    private let saveChanges: ((ModelContext) throws -> Void)?

    init(progress: StudyProgressSync? = nil, saveChanges: ((ModelContext) throws -> Void)? = nil) {
        self.progress = progress ?? .shared
        self.saveChanges = saveChanges
    }

    /// Called only following explicit confirmation or retry of that confirmation.
    /// A definitively rejected reset needs a new confirmation; uncertain work is
    /// always retried using its existing identity, scope and raw payload.
    func reset(scopeID: UUID, context: ModelContext, operationID: UUID? = nil,
               onPersisted: (UUID) -> Void = { _ in }) async throws {
        let accounts = progress.accounts
        let session = try accounts.session()
        guard let owner = accounts.ownerID else { throw StudyResetError.unavailable }
        let store = try makeStore(context)
        let existingID = try operationID ?? store.operations().last(where: {
            $0.scopeID == scopeID && $0.stateRawValue != StudyResetState.completed.rawValue && $0.stateRawValue != StudyResetState.rejected.rawValue
        })?.id
        let key = "\(owner)/\(scopeID)"
        guard progress.gate.resetCalls.insert(key).inserted else { throw StudyResetError.pending }
        defer { progress.gate.resetCalls.remove(key) }
        await progress.gate.acquire(owner)
        defer { progress.gate.release(owner) }
        try accounts.validate(session)
        try Task.checkCancellation()
        let operation: PendingStudyReset
        if let existingID {
            guard let saved = try store.operations().first(where: { $0.id == existingID && $0.scopeID == scopeID }) else { throw StudyResetError.unavailable }
            operation = saved
        } else {
            let snapshot = try await progress.authenticated(session: session) { try await self.progress.api.get(deckID: scopeID) }
            try accounts.validate(session)
            // Durable fence exists before the first reset POST. No local state
            // or pending learning is destructively modified yet.
            operation = try store.create(scopeID: scopeID, snapshot: snapshot)
        }
        onPersisted(operation.id)
        try await process(operation, store: store, context: context, session: session)
    }

    /// Caller owns the same account gate used by progress uploads. Lifecycle
    /// recovery does not create operations or repeat completed/rejected resets.
    func recover(context: ModelContext) async {
        guard let session = try? progress.accounts.session(), let store = try? makeStore(context),
              let records = try? store.operations() else { return }
        for operation in records where [StudyResetState.pending.rawValue, StudyResetState.confirmed.rawValue,
                                         StudyResetState.rejectedNeedsReconciliation.rawValue].contains(operation.stateRawValue) {
            do {
                try progress.accounts.validate(session)
                try await process(operation, store: store, context: context, session: session)
            } catch {
                #if DEBUG
                print("STUDY RESET deferred operation_id=\(operation.id)")
                #endif
            }
        }
    }

    private func makeStore(_ context: ModelContext) throws -> StudyResetStore {
        try StudyResetStore(context: context, accounts: progress.accounts,
                            saveChanges: saveChanges.map { save in { try save(context) } })
    }

    private func process(_ operation: PendingStudyReset, store: StudyResetStore,
                         context: ModelContext, session: UUID) async throws {
        try progress.accounts.validate(session)
        switch try store.state(operation) {
        case .completed: return
        case .rejected: throw StudyResetError.scopeChanged
        case .blocked: throw StudyResetError.blocked(operation.failureCode ?? "unknown")
        case .rejectedNeedsReconciliation:
            try await reconcileRejection(operation, store: store, context: context, session: session)
            throw StudyResetError.scopeChanged
        case .pending:
            do {
                let receipt = try await progress.authenticated(session: session) {
                    try await self.progress.api.reset(deckID: operation.scopeID, payload: operation.payloadData)
                }
                try progress.accounts.validate(session)
                try Self.validate(receipt, operation: operation)
                // If this save fails the pending operation still replays safely.
                try store.transition(operation, to: .confirmed, receipt: receipt)
            } catch {
                try progress.accounts.validate(session)
                let apiError = error as? APIError
                let code = apiError?.businessCode
                if code == "stale_progress_epoch" || code == "progress_scope_changed" {
                    try store.transition(operation, to: .rejectedNeedsReconciliation, code: code)
                    try await reconcileRejection(operation, store: store, context: context, session: session)
                    throw StudyResetError.scopeChanged
                }
                if let status = apiError?.statusCode, (400..<500).contains(status), ![401, 408, 425, 429].contains(status) {
                    let reason = code ?? "http_\(status)"
                    try store.transition(operation, to: .blocked, code: reason)
                    throw StudyResetError.blocked(reason)
                }
                throw error
            }
        case .confirmed: break
        }

        // A replay receipt can contain epochs older than today's reset by another
        // device. Read each ORIGINAL affected deck now; never cache receipt epochs.
        let fetchedAt = Date()
        var current: [UUID: UUID] = [:]
        for deck in try operation.request().expectedDecks {
            do {
                let snapshot = try await progress.authenticated(session: session) { try await self.progress.api.get(deckID: deck.deckID) }
                try progress.accounts.validate(session)
                guard snapshot.deckID == deck.deckID,
                      let fact = snapshot.decks.first(where: { $0.deckID == deck.deckID }) else { throw APIError.invalidResponse }
                current[deck.deckID] = fact.progressEpoch
            } catch {
                try progress.accounts.validate(session)
                // Content deleted after confirmed reset no longer has an epoch.
                guard (error as? APIError)?.statusCode == 404 else { throw error }
            }
        }
        try store.finish(operation, current: current, fetchedAt: fetchedAt)
        #if DEBUG
        print("STUDY RESET completed operation_id=\(operation.id)")
        #endif
    }

    private func reconcileRejection(_ operation: PendingStudyReset, store: StudyResetStore,
                                    context: ModelContext, session: UUID) async throws {
        let fetchedAt = Date()
        let snapshot = try await progress.authenticated(session: session) { try await self.progress.api.get(deckID: operation.scopeID) }
        try progress.accounts.validate(session)
        guard snapshot.deckID == operation.scopeID else { throw APIError.invalidResponse }
        let learningStore = try StudyProgressStore(modelContext: context, accounts: progress.accounts)
        for deck in snapshot.decks {
            do { try learningStore.cacheEpoch(deck.progressEpoch, for: deck.deckID, fetchedAt: fetchedAt) }
            catch StudyProgressStorageError.deckUnavailable { }
        }
        try store.transition(operation, to: .rejected, code: operation.failureCode)
    }

    static func validate(_ receipt: StudyProgressResetResponse, operation: PendingStudyReset) throws {
        let request = try operation.request()
        guard request.resetID == operation.id, receipt.resetID == operation.id, receipt.deckID == operation.scopeID,
              receipt.decks.count == request.expectedDecks.count,
              Set(receipt.decks.map(\.deckID)).count == receipt.decks.count else { throw APIError.invalidResponse }
        for expected in request.expectedDecks {
            guard let result = receipt.decks.first(where: { $0.deckID == expected.deckID }),
                  result.previousEpoch == expected.progressEpoch,
                  result.progressEpoch != result.previousEpoch, result.clearedCardCount >= 0 else { throw APIError.invalidResponse }
        }
    }
}
