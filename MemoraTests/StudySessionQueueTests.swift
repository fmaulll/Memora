import Foundation
import SwiftData
import Testing
@testable import Memora

struct StudySessionQueueTests {
    @Test func firstSuccessRequiresAnotherRecall() {
        let card = UUID()
        var queue = StudySessionQueue(cardIDs: [card])
        let completed1 = queue.rate(.good)
        #expect(!completed1)
        #expect(queue.cardIDs == [card])
        #expect(queue.confirmationIDs.contains(card))
        let completed2 = queue.rate(.good)
        #expect(completed2)
        #expect(queue.cardIDs.isEmpty)
        #expect(queue.confirmationIDs.isEmpty)
    }

    @Test func againRepeatsAndResetsConfirmation() {
        let card = UUID()
        var queue = StudySessionQueue(cardIDs: [card])
        for _ in 0..<5 {
            let completed3 = queue.rate(.again)
            #expect(!completed3)
            #expect(queue.cardIDs == [card])
        }
        let completed4 = queue.rate(.good)
        #expect(!completed4)
        let completed5 = queue.rate(.again)
        #expect(!completed5)
        #expect(queue.confirmationIDs.isEmpty)
        let completed6 = queue.rate(.good)
        #expect(!completed6)
        let completed7 = queue.rate(.good)
        #expect(completed7)
    }

    @Test func repeatsAreSpacedBetweenOtherCards() {
        let ids = (0..<5).map { _ in UUID() }
        var again = StudySessionQueue(cardIDs: ids)
        again.rate(.again)
        #expect(again.cardIDs == [ids[1], ids[0], ids[2], ids[3], ids[4]])
        var good = StudySessionQueue(cardIDs: ids)
        good.rate(.good)
        #expect(good.cardIDs == [ids[1], ids[2], ids[3], ids[0], ids[4]])
    }

    @Test func restoredQueueDropsDuplicateAndStaleConfirmationIDs() {
        let card = UUID()
        let queue = StudySessionQueue(cardIDs: [card, card], confirmationIDs: [card, UUID()])
        #expect(queue.cardIDs == [card])
        #expect(queue.confirmationIDs == [card])
    }

    @MainActor
    @Test func confirmationSurvivesPersistenceForBothSessionModes() throws {
        let container = try ModelContainer(
            for: StudyDeck.self, StudyFlashcardCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let card = StudyFlashcardCard(front: "Question", back: "Answer")
        let deck = StudyDeck(title: "Deck", subject: "Science", educationLevel: "University", cards: [card])
        container.mainContext.insert(deck)
        var queue = StudySessionQueue(cardIDs: [card.id])
        queue.rate(.good)
        deck.studyQueueIDs = queue.cardIDs
        deck.studyConfirmationIDs = Array(queue.confirmationIDs)
        deck.studyAllQueueIDs = queue.cardIDs
        deck.studyAllConfirmationIDs = Array(queue.confirmationIDs)
        try container.mainContext.save()

        let context = ModelContext(container)
        let saved = try #require(context.fetch(FetchDescriptor<StudyDeck>()).first)
        var single = StudySessionQueue(cardIDs: saved.studyQueueIDs, confirmationIDs: Set(saved.studyConfirmationIDs))
        var combined = StudySessionQueue(cardIDs: saved.studyAllQueueIDs, confirmationIDs: Set(saved.studyAllConfirmationIDs))
        let completed8 = single.rate(.good)
        #expect(completed8)
        let completed9 = combined.rate(.good)
        #expect(completed9)
    }

    @MainActor
    @Test func schedulingOnlyAdvancesAfterConfirmation() {
        let service = SpacedRepetitionService()
        let card = StudyFlashcardCard(front: "Q", back: "A")
        let now = Date(timeIntervalSince1970: 1_000_000)
        service.review(card: card, rating: .good, isConfirmed: false, now: now)
        #expect(card.interval == 0)
        #expect(card.correctCount == 0)
        #expect(card.nextReviewAt == now.addingTimeInterval(600))
        service.review(card: card, rating: .good, isConfirmed: true, now: now)
        #expect(card.interval == 1)
        #expect(card.reviewCount == 2)
        #expect(card.correctCount == 1)
        #expect(card.nextReviewAt == Calendar.current.date(byAdding: .day, value: 1, to: now))
    }

    @MainActor
    @Test func lapseResetsLongIntervalAndRequiresRelearning() {
        let service = SpacedRepetitionService()
        let card = StudyFlashcardCard(front: "Q", back: "A")
        card.interval = 20
        let now = Date(timeIntervalSince1970: 1_000_000)
        service.review(card: card, rating: .again, isConfirmed: false, now: now)
        #expect(card.interval == 0)
        #expect(card.nextReviewAt == now.addingTimeInterval(60))
        service.review(card: card, rating: .good, isConfirmed: false, now: now)
        #expect(card.interval == 0)
        service.review(card: card, rating: .good, isConfirmed: true, now: now)
        #expect(card.interval == 1)
    }
}
