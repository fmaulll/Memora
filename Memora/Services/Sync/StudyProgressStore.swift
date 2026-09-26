import Foundation
import SwiftData

/// Value captured before a future study operation. Refreshing a deck does not
/// alter it. Unknown remains unknown, even if an epoch is fetched later.
struct StudyProgressContext: Equatable {
    let accountID: UUID
    let deckID: UUID
    let epoch: UUID?

    fileprivate init(accountID: UUID, deckID: UUID, epoch: UUID?) {
        self.accountID = accountID
        self.deckID = deckID
        self.epoch = epoch
    }
}

struct PendingStudyProgressSnapshot: Identifiable {
    let id: UUID
    let accountID: UUID
    let createdAt: Date
    let state: PendingStudyProgressState
    let events: [PendingStudyEvent]
    let operationID: UUID?
    let completedAt: Date?
}

struct SealedStudyProgressUpload: Equatable {
    let batchID: UUID
    let accountID: UUID
    let operationID: UUID
    let completedAt: Date
    let payload: Data
}

/// Local persistence only. No HTTP, queue changes, retry policy or sync triggers.
/// Bind one instance to one active LocalAccountStore session. Recreate it after
/// authentication/account changes; stale instances cannot read or mutate work.
@MainActor
final class StudyProgressStore {
    private let modelContext: ModelContext
    private let accounts: LocalAccountStore
    private let session: UUID
    private let accountID: UUID

    init(modelContext: ModelContext, accounts: LocalAccountStore? = nil) throws {
        let accounts = accounts ?? .shared
        session = try accounts.session()
        guard let accountID = accounts.ownerID else { throw StudyProgressStorageError.accountUnavailable }
        self.accountID = accountID
        self.accounts = accounts
        self.modelContext = modelContext
    }

    func captureContext(deckID: UUID) throws -> StudyProgressContext {
        try validateAccount()
        let deck = try owningDeck(deckID)
        return StudyProgressContext(accountID: accountID, deckID: deckID, epoch: deck.cachedProgressEpoch)
    }

    /// Call only with an epoch from a backend progress snapshot, never a receipt.
    /// The captured operation contexts and pending event data are independent.
    func cacheEpoch(_ epoch: UUID, for deckID: UUID, fetchedAt: Date) throws {
        try validateAccount()
        let deck = try owningDeck(deckID)
        if let previousFetch = deck.progressEpochFetchedAt, previousFetch > fetchedAt { return }
        try save {
            deck.cachedProgressEpoch = epoch
            deck.progressEpochFetchedAt = fetchedAt
        }
    }

    @discardableResult
    func createDraft() throws -> PendingStudyProgressSnapshot {
        try validateAccount()
        let record = PendingStudyProgress(accountID: accountID)
        try save { modelContext.insert(record) }
        return try snapshot(record)
    }

    /// The caller supplies a stable ID once for the qualifying transition and
    /// reuses it if a local save must be retried. No epoch lookup happens here.
    @discardableResult
    func append(eventID: UUID, cardID: UUID, context: StudyProgressContext,
                completedAt: Date, to draftID: UUID) throws -> PendingStudyProgressSnapshot {
        try validateAccount()
        guard context.accountID == accountID else { throw StudyProgressStorageError.wrongAccount }
        guard let epoch = context.epoch else { throw StudyProgressStorageError.unknownEpoch }
        let record = try find(draftID)
        guard record.stateRawValue == PendingStudyProgressState.draft.rawValue else {
            throw StudyProgressStorageError.sealedBatch
        }
        let event = PendingStudyEvent(id: eventID, cardID: cardID, deckID: context.deckID,
                                      progressEpoch: epoch, completedAt: completedAt)
        for other in try records() where other.id != draftID {
            if let existing = try other.events().first(where: { $0.id == eventID }) {
                guard existing == event else { throw StudyProgressStorageError.eventIdentityConflict }
                throw StudyProgressStorageError.eventAlreadyRecordedInAnotherBatch
            }
        }
        try save { try record.append(event) }
        return try snapshot(record)
    }

    func pending() throws -> [PendingStudyProgressSnapshot] {
        try validateAccount()
        return try records().map(snapshot)
    }

    func pending(batchID: UUID) throws -> PendingStudyProgressSnapshot {
        try validateAccount()
        return try snapshot(find(batchID))
    }

    /// S4 must explicitly choose a batch-completion timestamp; there is no .now
    /// default that could silently timestamp old offline work at retry time.
    func seal(draftID: UUID, completedAt: Date) throws -> SealedStudyProgressUpload {
        try validateAccount()
        let record = try find(draftID)
        try save { try record.seal(completedAt: completedAt) }
        return try sealedUpload(batchID: draftID)
    }

    func sealedUpload(batchID: UUID) throws -> SealedStudyProgressUpload {
        try validateAccount()
        let record = try find(batchID)
        guard record.stateRawValue == PendingStudyProgressState.sealed.rawValue,
              let operationID = record.operationID, let completedAt = record.completedAt,
              let payload = record.payloadData else { throw StudyProgressStorageError.corruptRecord }
        return SealedStudyProgressUpload(batchID: record.id, accountID: accountID,
                                         operationID: operationID, completedAt: completedAt, payload: payload)
    }

    private func validateAccount() throws {
        try accounts.validate(session)
        guard accounts.ownerID == accountID else { throw StudyProgressStorageError.wrongAccount }
    }

    private func owningDeck(_ id: UUID) throws -> StudyDeck {
        let descriptor = FetchDescriptor<StudyDeck>(predicate: #Predicate { $0.id == id })
        guard let deck = try modelContext.fetch(descriptor).first, !deck.needsDeletion,
              !deck.childDecks.contains(where: { !$0.needsDeletion }) else {
            throw StudyProgressStorageError.deckUnavailable
        }
        return deck
    }

    private func records() throws -> [PendingStudyProgress] {
        let owner = accountID
        return try modelContext.fetch(FetchDescriptor<PendingStudyProgress>(
            predicate: #Predicate { $0.accountID == owner }, sortBy: [SortDescriptor(\.createdAt)]
        ))
    }

    private func find(_ id: UUID) throws -> PendingStudyProgress {
        let owner = accountID
        let descriptor = FetchDescriptor<PendingStudyProgress>(
            predicate: #Predicate { $0.id == id && $0.accountID == owner }
        )
        guard let record = try modelContext.fetch(descriptor).first else { throw StudyProgressStorageError.notFound }
        return record
    }

    private func snapshot(_ record: PendingStudyProgress) throws -> PendingStudyProgressSnapshot {
        guard let state = PendingStudyProgressState(rawValue: record.stateRawValue) else {
            throw StudyProgressStorageError.corruptRecord
        }
        return PendingStudyProgressSnapshot(id: record.id, accountID: record.accountID,
            createdAt: record.createdAt, state: state, events: try record.events(),
            operationID: record.operationID, completedAt: record.completedAt)
    }

    private func save(_ change: () throws -> Void) throws {
        do {
            try change()
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
