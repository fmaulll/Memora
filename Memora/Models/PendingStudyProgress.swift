import Foundation
import SwiftData

struct PendingStudyEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let cardID: UUID
    let deckID: UUID
    let progressEpoch: UUID
    let completedAt: Date
}

enum PendingStudyProgressState: String {
    case draft
    case sealed
    case reconciliationRequired
    case terminalFailure
}

enum StudyProgressStorageError: Error, Equatable {
    case accountUnavailable
    case notFound
    case unknownEpoch
    case deckUnavailable
    case wrongAccount
    case sealedBatch
    case emptyBatch
    case eventIdentityConflict
    case eventAlreadyRecordedInAnotherBatch
    case mixedEpochs
    case cardOwnershipConflict
    case submissionLimitExceeded
    case invalidCompletionTime
    case corruptRecord
}

/// No relationships: these operations must outlive deck/card cache deletion.
/// Only guarded methods can change a draft. Sealed content is never rebuilt.
@Model
final class PendingStudyProgress {
    private(set) var id: UUID
    private(set) var accountID: UUID
    private(set) var createdAt: Date
    private(set) var stateRawValue: String
    private(set) var eventsData: Data
    private(set) var operationID: UUID?
    private(set) var payloadData: Data?
    private(set) var completedAt: Date?
    private(set) var failureCode: String?

    init(accountID: UUID, createdAt: Date = .now) {
        id = UUID()
        self.accountID = accountID
        self.createdAt = createdAt
        stateRawValue = PendingStudyProgressState.draft.rawValue
        eventsData = Data("[]".utf8)
    }

    func block(code: String, reconcile: Bool) {
        // Failure metadata never changes the immutable operation or its events.
        failureCode = code
        stateRawValue = (reconcile ? PendingStudyProgressState.reconciliationRequired : .terminalFailure).rawValue
    }

    // Restore live observed state after a failed transaction/SwiftData rollback.
    // This never changes event identity or sealed request bytes.
    func restoreFailureState(_ state: String, code: String?) {
        stateRawValue = state
        failureCode = code
    }

    func events() throws -> [PendingStudyEvent] {
        // Local event timestamps retain full Date precision, independent of the
        // backend's wire encoder. A malformed record must never become empty work.
        try JSONDecoder().decode([PendingStudyEvent].self, from: eventsData)
    }

    func append(_ event: PendingStudyEvent) throws {
        guard stateRawValue == PendingStudyProgressState.draft.rawValue else {
            throw StudyProgressStorageError.sealedBatch
        }
        var events = try events()
        if let existing = events.first(where: { $0.id == event.id }) {
            guard existing == event else { throw StudyProgressStorageError.eventIdentityConflict }
            return
        }
        guard !events.contains(where: { $0.deckID == event.deckID && $0.progressEpoch != event.progressEpoch }) else {
            throw StudyProgressStorageError.mixedEpochs
        }
        guard !events.contains(where: { $0.cardID == event.cardID && $0.deckID != event.deckID }) else {
            throw StudyProgressStorageError.cardOwnershipConflict
        }
        guard event.completedAt.timeIntervalSince1970.isFinite else {
            throw StudyProgressStorageError.invalidCompletionTime
        }
        events.append(event)
        guard Set(events.map(\.deckID)).count <= 100, Set(events.map(\.cardID)).count <= 5000 else {
            throw StudyProgressStorageError.submissionLimitExceeded
        }
        eventsData = try JSONEncoder().encode(events)
    }

    func seal(completedAt: Date) throws {
        guard stateRawValue == PendingStudyProgressState.draft.rawValue else {
            throw StudyProgressStorageError.sealedBatch
        }
        let events = try events()
        guard !events.isEmpty else { throw StudyProgressStorageError.emptyBatch }
        guard completedAt.timeIntervalSince1970.isFinite else {
            throw StudyProgressStorageError.invalidCompletionTime
        }
        let groups = Dictionary(grouping: events, by: \.deckID)
        let decks = try groups.keys.sorted(by: { $0.uuidString < $1.uuidString }).map { deckID in
            let group = groups[deckID]!
            let epochs = Set(group.map(\.progressEpoch))
            guard epochs.count == 1, let epoch = epochs.first else {
                throw StudyProgressStorageError.mixedEpochs
            }
            let cards = Set(group.map(\.cardID)).sorted { $0.uuidString < $1.uuidString }
            return DeckLearnedTransitions(deckID: deckID, progressEpoch: epoch,
                                         learnedCards: cards.map { LearnedCardTransition(cardID: $0) })
        }
        let operationID = UUID()
        let request = StudyProgressSubmission(sessionID: operationID, completedAt: completedAt, decks: decks)
        let payload = try APIJSON.makeEncoder().encode(request)
        // Keep the persisted request timestamp identical to the timestamp actually
        // encoded by the wire codec. Individual event times remain untouched.
        let encodedRequest = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: payload)
        self.operationID = operationID
        self.completedAt = encodedRequest.completedAt
        payloadData = payload
        stateRawValue = PendingStudyProgressState.sealed.rawValue
    }
}
