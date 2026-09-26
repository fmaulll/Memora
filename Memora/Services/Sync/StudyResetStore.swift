import Foundation
import SwiftData

@MainActor
final class StudyResetStore {
    private let context: ModelContext
    private let accounts: LocalAccountStore
    private let owner: UUID
    private let session: UUID
    private let saveChanges: () throws -> Void

    init(context: ModelContext, accounts: LocalAccountStore, saveChanges: (() throws -> Void)? = nil) throws {
        self.context = context
        self.accounts = accounts
        session = try accounts.session()
        guard let owner = accounts.ownerID else { throw StudyResetError.unavailable }
        self.owner = owner
        self.saveChanges = saveChanges ?? { try context.save() }
    }

    func operations() throws -> [PendingStudyReset] {
        try accounts.validate(session)
        let owner = owner
        return try context.fetch(FetchDescriptor<PendingStudyReset>(predicate: #Predicate { $0.accountID == owner },
            sortBy: [SortDescriptor(\.createdAt)]))
    }

    func create(scopeID: UUID, snapshot: StudyProgressResponse) throws -> PendingStudyReset {
        try accounts.validate(session)
        guard snapshot.deckID == scopeID, !snapshot.decks.isEmpty,
              Set(snapshot.decks.map(\.deckID)).count == snapshot.decks.count else { throw APIError.invalidResponse }
        let expected = snapshot.decks.map { DeckProgressEpoch(deckID: $0.deckID, progressEpoch: $0.progressEpoch) }
            .sorted { $0.deckID.uuidString < $1.deckID.uuidString }
        let ids = Set(expected.map(\.deckID))
        for operation in try operations() where try state(operation).fencesStudy {
            if !ids.isDisjoint(with: try operation.request().expectedDecks.map(\.deckID)) { throw StudyResetError.pending }
        }
        let operation = try PendingStudyReset(accountID: owner, scopeID: scopeID, expected: expected)
        try save { context.insert(operation) }
        return operation
    }

    func state(_ operation: PendingStudyReset) throws -> StudyResetState {
        guard operation.accountID == owner, let state = StudyResetState(rawValue: operation.stateRawValue) else {
            throw StudyProgressStorageError.corruptRecord
        }
        return state
    }

    func transition(_ operation: PendingStudyReset, to state: StudyResetState, code: String? = nil,
                    receipt: StudyProgressResetResponse? = nil) throws {
        try accounts.validate(session)
        guard operation.accountID == owner else { throw StudyProgressStorageError.wrongAccount }
        try save { try operation.transition(state, code: code, receipt: receipt) }
    }

    /// A single save commits intentional local clearing, current epoch cache,
    /// pending-learning retirement, and reset completion. No receipt epoch writes.
    func finish(_ operation: PendingStudyReset, current: [UUID: UUID], fetchedAt: Date) throws {
        try accounts.validate(session)
        guard try state(operation) == .confirmed else { throw StudyProgressStorageError.corruptRecord }
        let ids = Set(try operation.request().expectedDecks.map(\.deckID))
        let decks = try context.fetch(FetchDescriptor<StudyDeck>()).filter { ids.contains($0.id) }
        let owner = owner
        let learning = try context.fetch(FetchDescriptor<PendingStudyProgress>(predicate: #Predicate { $0.accountID == owner }))
        let restoreDecks = decks.map(Self.captureLocalState)
        let restoreLearning: [() -> Void] = learning.map { record in
            let state = record.stateRawValue, code = record.failureCode
            return { record.restoreFailureState(state, code: code) }
        }
        do {
            try save {
                for record in learning {
                    guard try record.events().contains(where: { ids.contains($0.deckID) }) else { continue }
                    // Preserve previous S4 rejection markers. Mixed-scope immutable
                    // submissions are retired whole; never rewrite their payload.
                    if record.stateRawValue == PendingStudyProgressState.draft.rawValue || record.stateRawValue == PendingStudyProgressState.sealed.rawValue {
                        record.block(code: "superseded_by_reset", reconcile: false)
                    }
                }
                for deck in decks {
                    for card in deck.cards where !card.needsDeletion {
                        card.reviewCount = 0; card.correctCount = 0
                        card.lastReviewedAt = nil; card.nextReviewAt = nil
                        card.difficulty = 0; card.interval = 0
                    }
                    deck.studyQueueIDs = []; deck.learningQueueIDs = []
                    deck.studyCompletedCount = 0; deck.isStudySessionActive = false
                    deck.studyBatchCardIDs = []; deck.studyProgressBindingData = nil
                    deck.studyAllQueueIDs = []; deck.studyAllLearningQueueIDs = []
                    deck.studyAllCompletedCount = 0; deck.isStudyAllSessionActive = false
                    deck.studyAllBatchCardIDs = []; deck.studyAllProgressBindingData = nil
                    if deck.progressEpochFetchedAt == nil || deck.progressEpochFetchedAt! <= fetchedAt {
                        deck.cachedProgressEpoch = current[deck.id]
                        deck.progressEpochFetchedAt = fetchedAt
                    }
                    deck.lastStudyResetID = operation.id
                }
                try operation.transition(.completed)
            }
        } catch {
            // Like S3's answer transaction, rollback alone does not reliably
            // restore values already observed by SwiftUI. Restore without saving.
            restoreDecks.forEach { $0() }
            restoreLearning.forEach { $0() }
            try operation.transition(.confirmed)
            throw error
        }
    }

    private static func captureLocalState(_ deck: StudyDeck) -> () -> Void {
        let normal = (deck.studyQueueIDs, deck.learningQueueIDs, deck.studyBatchCardIDs,
                      deck.studyCompletedCount, deck.isStudySessionActive, deck.studyProgressBindingData)
        let combined = (deck.studyAllQueueIDs, deck.studyAllLearningQueueIDs, deck.studyAllBatchCardIDs,
                        deck.studyAllCompletedCount, deck.isStudyAllSessionActive, deck.studyAllProgressBindingData)
        let cache = (deck.cachedProgressEpoch, deck.progressEpochFetchedAt, deck.lastStudyResetID)
        let restoreCards: [() -> Void] = deck.cards.filter { !$0.needsDeletion }.map { card in
            let values = (card.reviewCount, card.correctCount, card.lastReviewedAt, card.nextReviewAt, card.difficulty, card.interval)
            return {
                card.reviewCount = values.0; card.correctCount = values.1
                card.lastReviewedAt = values.2; card.nextReviewAt = values.3
                card.difficulty = values.4; card.interval = values.5
            }
        }
        return {
            deck.studyQueueIDs = normal.0; deck.learningQueueIDs = normal.1; deck.studyBatchCardIDs = normal.2
            deck.studyCompletedCount = normal.3; deck.isStudySessionActive = normal.4; deck.studyProgressBindingData = normal.5
            deck.studyAllQueueIDs = combined.0; deck.studyAllLearningQueueIDs = combined.1; deck.studyAllBatchCardIDs = combined.2
            deck.studyAllCompletedCount = combined.3; deck.isStudyAllSessionActive = combined.4; deck.studyAllProgressBindingData = combined.5
            deck.cachedProgressEpoch = cache.0; deck.progressEpochFetchedAt = cache.1; deck.lastStudyResetID = cache.2
            restoreCards.forEach { $0() }
        }
    }

    /// This local safety read also works while auth is suspended. It reveals no
    /// other account's operations and prevents offline local-only reset bypass.
    static func assertStudyAllowed(context: ModelContext, owner: UUID?, deckIDs: Set<UUID>) throws {
        guard let owner else { return }
        let records = try context.fetch(FetchDescriptor<PendingStudyReset>(predicate: #Predicate {
            $0.accountID == owner && $0.stateRawValue != "completed" && $0.stateRawValue != "rejected"
        }))
        for record in records {
            guard let state = StudyResetState(rawValue: record.stateRawValue) else { throw StudyProgressStorageError.corruptRecord }
            if state.fencesStudy, !deckIDs.isDisjoint(with: try record.request().expectedDecks.map(\.deckID)) {
                throw StudyResetError.pending
            }
        }
    }

    func uploadIsFenced(deckIDs: Set<UUID>) throws -> Bool {
        try accounts.validate(session)
        for operation in try operations() where try state(operation).fencesStudy {
            if !deckIDs.isDisjoint(with: try operation.request().expectedDecks.map(\.deckID)) { return true }
        }
        return false
    }

    private func save(_ change: () throws -> Void) throws {
        do { try change(); try saveChanges() }
        catch { context.rollback(); throw error }
    }
}
