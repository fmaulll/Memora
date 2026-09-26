import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct StudyResetMigrationTests {
    @Test func s4StoreMigratesWithoutLosingQueuesBindingsOrSealedLearning() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        let owner = UUID(), epoch = UUID()
        let saved = try autoreleasepool {
            let schema = Schema([Item.self, PreS5Models.StudyDeck.self, PreS5Models.StudyFlashcardCard.self,
                                 LocalUserProfile.self, PendingStudyProgress.self])
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let deck = PreS5Models.StudyDeck(title: "Keep my chapter", subject: "Science", educationLevel: "College")
            context.insert(deck)
            let card = PreS5Models.StudyFlashcardCard(front: "Keep question", back: "Keep answer", deck: deck)
            context.insert(card); card.reviewCount = 9; card.correctCount = 7
            deck.cachedProgressEpoch = epoch
            deck.studyQueueIDs = [card.id]; deck.learningQueueIDs = [card.id]; deck.studyBatchCardIDs = [card.id]
            deck.studyAllQueueIDs = [card.id]; deck.studyAllLearningQueueIDs = [card.id]; deck.studyAllBatchCardIDs = [card.id]
            deck.isStudySessionActive = true; deck.isStudyAllSessionActive = true
            let pending = PendingStudyProgress(accountID: owner)
            try pending.append(PendingStudyEvent(id: UUID(), cardID: card.id, deckID: deck.id, progressEpoch: epoch, completedAt: Date(timeIntervalSince1970: 1700000000)))
            try pending.seal(completedAt: Date(timeIntervalSince1970: 1700000000))
            context.insert(pending)
            let binding = try JSONEncoder().encode(StudySessionEpochBinding(accountID: owner, epoch: epoch, draftID: pending.id))
            deck.studyProgressBindingData = binding; deck.studyAllProgressBindingData = binding
            try context.save()
            return (deck.id, card.id, binding, pending.id, pending.payloadData, pending.operationID)
        }
        try autoreleasepool {
            let schema = MemoraSchema.current
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            let deck = try #require(context.fetch(FetchDescriptor<StudyDeck>()).first)
            let card = try #require(deck.cards.first)
            #expect(deck.id == saved.0 && deck.title == "Keep my chapter" && deck.cachedProgressEpoch == epoch)
            #expect(deck.lastStudyResetID == nil)
            #expect(deck.studyQueueIDs == [saved.1] && deck.learningQueueIDs == [saved.1] && deck.studyBatchCardIDs == [saved.1])
            #expect(deck.studyAllQueueIDs == [saved.1] && deck.studyAllLearningQueueIDs == [saved.1] && deck.studyAllBatchCardIDs == [saved.1])
            #expect(deck.isStudySessionActive && deck.isStudyAllSessionActive)
            #expect(deck.studyProgressBindingData == saved.2 && deck.studyAllProgressBindingData == saved.2)
            #expect(card.id == saved.1 && card.reviewCount == 9 && card.correctCount == 7 && card.front == "Keep question")
            let pending = try #require(context.fetch(FetchDescriptor<PendingStudyProgress>()).first)
            #expect(pending.id == saved.3 && pending.payloadData == saved.4 && pending.operationID == saved.5)
            #expect(try context.fetch(FetchDescriptor<PendingStudyReset>()).isEmpty)
        }
    }
}
