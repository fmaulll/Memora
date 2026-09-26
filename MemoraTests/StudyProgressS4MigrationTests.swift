import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct StudyProgressS4MigrationTests {
    @Test func s3DiskStorePreservesDraftsSealedBytesAndActiveSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        let owner = UUID(), epoch = UUID(), cardID = UUID(), deckID = UUID(), operationID = UUID()
        let time = Date(timeIntervalSince1970: 1700000000)
        let event = PendingStudyEvent(id: UUID(), cardID: cardID, deckID: deckID, progressEpoch: epoch, completedAt: time)
        let events = try JSONEncoder().encode([event])
        let payload = try APIJSON.makeEncoder().encode(StudyProgressSubmission(sessionID: operationID, completedAt: time,
            decks: [DeckLearnedTransitions(deckID: deckID, progressEpoch: epoch, learnedCards: [LearnedCardTransition(cardID: cardID)])]))
        let ids = try autoreleasepool {
            let schema = Schema([Item.self, StudyDeck.self, StudyFlashcardCard.self, LocalUserProfile.self, S3Models.PendingStudyProgress.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let draft = S3Models.PendingStudyProgress(accountID: owner, eventsData: events)
            let sealed = S3Models.PendingStudyProgress(accountID: owner, eventsData: events,
                operationID: operationID, payloadData: payload, completedAt: time)
            context.insert(draft); context.insert(sealed)
            let deck = StudyDeck(title: "Existing chapter", subject: "Science", educationLevel: "College")
            deck.id = deckID; deck.cachedProgressEpoch = epoch; deck.progressEpochFetchedAt = time
            context.insert(deck)
            let card = StudyFlashcardCard(front: "Preserve question", back: "Preserve answer", deck: deck)
            card.id = cardID; card.reviewCount = 8; context.insert(card)
            deck.isStudySessionActive = true; deck.learningQueueIDs = [cardID]; deck.studyBatchCardIDs = [cardID]
            deck.studyProgressBindingData = try JSONEncoder().encode(StudySessionEpochBinding(accountID: owner, epoch: epoch, draftID: draft.id))
            try context.save()
            return (draft.id, sealed.id)
        }
        try autoreleasepool {
            let schema = MemoraSchema.current
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let records = try context.fetch(FetchDescriptor<PendingStudyProgress>())
            #expect(records.count == 2 && records.allSatisfy { $0.failureCode == nil })
            let draft = try #require(records.first { $0.id == ids.0 })
            let sealed = try #require(records.first { $0.id == ids.1 })
            #expect(draft.eventsData == events && draft.stateRawValue == "draft")
            #expect(sealed.eventsData == events && sealed.stateRawValue == "sealed")
            #expect(sealed.operationID == operationID && sealed.payloadData == payload && sealed.completedAt == time)
            let deck = try #require(context.fetch(FetchDescriptor<StudyDeck>()).first)
            #expect(deck.cachedProgressEpoch == epoch && deck.learningQueueIDs == [cardID] && deck.isStudySessionActive)
            let binding = try JSONDecoder().decode(StudySessionEpochBinding.self, from: #require(deck.studyProgressBindingData))
            #expect(binding.draftID == draft.id && binding.epoch == epoch)
            let card = try #require(deck.cards.first)
            #expect(card.id == cardID && card.reviewCount == 8 && card.front == "Preserve question")
        }
    }
}

// Exact pre-S4 entity layout. Other models did not change in S4.
private enum S3Models {
    @Model final class PendingStudyProgress {
        private(set) var id: UUID
        private(set) var accountID: UUID
        private(set) var createdAt: Date
        private(set) var stateRawValue: String
        private(set) var eventsData: Data
        private(set) var operationID: UUID?
        private(set) var payloadData: Data?
        private(set) var completedAt: Date?

        init(accountID: UUID, eventsData: Data, operationID: UUID? = nil, payloadData: Data? = nil, completedAt: Date? = nil) {
            id = UUID(); self.accountID = accountID; createdAt = Date()
            stateRawValue = operationID == nil ? "draft" : "sealed"
            self.eventsData = eventsData; self.operationID = operationID
            self.payloadData = payloadData; self.completedAt = completedAt
        }
    }
}
