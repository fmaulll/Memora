import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct StudyProgressSummaryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }

    @Test func nestedDecksAreCountedOnceAndDeletedContentIsExcluded() throws {
        let container = try makeContainer()
        let root = makeDeck("Root", context: container.mainContext)
        let chapter = makeDeck("Chapter", context: container.mainContext, parent: root)
        let nested = makeDeck("Nested", context: container.mainContext, parent: chapter)
        let deleted = makeDeck("Deleted", context: container.mainContext, parent: root)
        deleted.needsDeletion = true
        addCard(to: root)
        addCard(to: chapter)
        addCard(to: nested)
        addCard(to: deleted)
        let deletedCard = addCard(to: root)
        deletedCard.needsDeletion = true
        let summary = StudyProgressSummary(decks: [root, chapter, nested, deleted], isSubscribed: true, now: now)
        #expect(summary.decks.count == 1)
        #expect(summary.totalCards == 3)
        #expect(summary.newCards == 3)
        #expect(summary.decks.first?.descendants.count == 2)
    }

    @Test func confirmationAndLapsesAreNotReportedAsLearned() throws {
        let container = try makeContainer()
        let deck = makeDeck("Deck", context: container.mainContext)
        addCard(to: deck)
        let learned = addCard(to: deck)
        learned.reviewCount = 2
        learned.correctCount = 1
        learned.interval = 1
        let lapse = addCard(to: deck)
        lapse.reviewCount = 3
        lapse.correctCount = 1
        lapse.interval = 0
        let pending = addCard(to: deck)
        pending.reviewCount = 3
        pending.correctCount = 1
        pending.interval = 2
        deck.isStudySessionActive = true
        deck.studyConfirmationIDs = [pending.id]
        deck.studyQueueIDs = [pending.id, lapse.id]
        let summary = DeckProgressSummary(deck: deck, isSubscribed: true, now: now)
        #expect(summary.newCount == 1)
        #expect(summary.learningCount == 2)
        #expect(summary.confirmedCount == 1)
        #expect(summary.sessionRemaining == 2)
        #expect(summary.sessionTotal == 4)
    }

    @Test func recommendationsFindSessionsInsideChapters() throws {
        let container = try makeContainer()
        let root = makeDeck("Root", context: container.mainContext)
        let child = makeDeck("Chapter", context: container.mainContext, parent: root)
        let card = addCard(to: child)
        child.isStudySessionActive = true
        child.studyQueueIDs = [card.id, UUID()]
        let summary = StudyProgressSummary(decks: [root, child], isSubscribed: true, now: now)
        #expect(summary.activeSessions == 1)
        #expect(summary.recommended?.resumeDeck?.id == child.id)
        #expect(summary.recommended?.sessionRemaining == 1)
    }

    @Test func lockedDecksRemainVisibleButAreNotRecommendedOrScheduled() throws {
        let container = try makeContainer()
        let deck = makeDeck("Locked", context: container.mainContext)
        deck.requiresSubscription = true
        let card = addCard(to: deck)
        card.reviewCount = 1
        card.nextReviewAt = now.addingTimeInterval(-60)
        let summary = StudyProgressSummary(decks: [deck], isSubscribed: false, now: now)
        #expect(summary.totalCards == 1)
        #expect(summary.dueCards == 0)
        #expect(summary.recommended == nil)
        #expect(summary.decks[0].scheduledCount(on: now) == 0)
        let unlocked = StudyProgressSummary(decks: [deck], isSubscribed: true, now: now)
        #expect(unlocked.dueCards == 1)
    }

    @Test func dailyCountIsUniqueCardsAndUpcomingUsesExactCalendarDay() throws {
        let container = try makeContainer()
        let deck = makeDeck("Deck", context: container.mainContext)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: now))
        let card = addCard(to: deck)
        card.reviewCount = 12
        card.lastReviewedAt = now.addingTimeInterval(-60)
        card.nextReviewAt = tomorrow
        let old = addCard(to: deck)
        old.reviewCount = 8
        old.lastReviewedAt = now.addingTimeInterval(-86_400)
        old.nextReviewAt = now.addingTimeInterval(-60)
        let summary = DeckProgressSummary(deck: deck, isSubscribed: true, now: now, calendar: calendar)
        #expect(summary.studiedTodayCount == 1)
        #expect(summary.dueCount == 1)
        #expect(summary.scheduledCount(on: tomorrow, calendar: calendar) == 1)
        #expect(summary.lastStudiedAt == card.lastReviewedAt)
        #expect(summary.nextReviewAt == tomorrow)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: StudyDeck.self, StudyFlashcardCard.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeDeck(_ title: String, context: ModelContext, parent: StudyDeck? = nil) -> StudyDeck {
        let deck = StudyDeck(title: title, subject: "Science", educationLevel: "University", parentDeck: parent)
        context.insert(deck)
        return deck
    }

    @discardableResult
    private func addCard(to deck: StudyDeck) -> StudyFlashcardCard {
        let card = StudyFlashcardCard(front: "Question", back: "Answer")
        deck.cards.append(card)
        return card
    }
}
