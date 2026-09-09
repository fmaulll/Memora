import Foundation

/// A current-state summary, not a historical activity log.
@MainActor
struct DeckProgressSummary: Identifiable {
    nonisolated let id: UUID
    let deck: StudyDeck
    let cards: [StudyFlashcardCard]
    let descendants: [StudyDeck]
    let newCount: Int
    let learningCount: Int
    let confirmedCount: Int
    let dueCount: Int
    let studiedTodayCount: Int
    let lastStudiedAt: Date?
    let nextReviewAt: Date?
    let sessionRemaining: Int
    let sessionTotal: Int
    let resumeDeck: StudyDeck?
    let isLocked: Bool
    let isGenerating: Bool
    let hasGenerationFailure: Bool

    var totalCount: Int { cards.count }
    var hasActiveSession: Bool { sessionRemaining > 0 }
    var confirmedFraction: Double {
        totalCount == 0 ? 0 : Double(confirmedCount) / Double(totalCount)
    }

    init(deck: StudyDeck, isSubscribed: Bool, now: Date, calendar: Calendar = .current) {
        self.id = deck.id
        self.deck = deck
        var visitedDecks = Set<UUID>()
        var visitedCards = Set<UUID>()
        var members: [StudyDeck] = []
        var cards: [StudyFlashcardCard] = []
        func visit(_ current: StudyDeck) {
            guard !current.needsDeletion, visitedDecks.insert(current.id).inserted else { return }
            members.append(current)
            cards.append(contentsOf: current.cards.filter {
                !$0.needsDeletion && visitedCards.insert($0.id).inserted
            })
            for child in current.childDecks.sorted(by: StudyDeck.chapterOrder) { visit(child) }
        }
        visit(deck)
        self.cards = cards
        descendants = Array(members.dropFirst())
        isLocked = deck.needsSubscription && !isSubscribed
        isGenerating = members.contains { $0.generationStatus == "generating" }
        hasGenerationFailure = members.contains { $0.generationStatus == "failed" }

        var confirmationIDs = Set<UUID>()
        var remainingIDs = Set<UUID>()
        var sessionIDs = Set<UUID>()
        for member in members {
            if member.isStudySessionActive {
                remainingIDs.formUnion(member.studyQueueIDs + member.learningQueueIDs)
                confirmationIDs.formUnion(member.studyConfirmationIDs)
            }
            if member.isStudyAllSessionActive {
                remainingIDs.formUnion(member.studyAllQueueIDs + member.studyAllLearningQueueIDs)
                confirmationIDs.formUnion(member.studyAllConfirmationIDs)
            }
            if member.isStudySessionActive || member.isStudyAllSessionActive {
                sessionIDs.formUnion(member.cards.filter { !$0.needsDeletion }.map(\.id))
            }
        }
        sessionRemaining = remainingIDs.intersection(visitedCards).count
        sessionTotal = sessionIDs.intersection(visitedCards).count
        // Combined sessions are continued from the parent's chapter list.
        resumeDeck = members.contains { $0.isStudyAllSessionActive }
            ? deck : members.first { $0.isStudySessionActive }
        newCount = cards.filter { $0.reviewCount == 0 }.count
        confirmedCount = cards.filter {
            $0.reviewCount > 0 && $0.correctCount > 0 && $0.interval > 0 && !confirmationIDs.contains($0.id)
        }.count
        learningCount = cards.count - newCount - confirmedCount
        dueCount = isLocked ? 0 : cards.filter {
            $0.reviewCount > 0 && ($0.nextReviewAt.map { $0 <= now } ?? false)
        }.count
        studiedTodayCount = cards.filter {
            guard let date = $0.lastReviewedAt else { return false }
            return date <= now && calendar.isDate(date, inSameDayAs: now)
        }.count
        lastStudiedAt = cards.compactMap(\.lastReviewedAt).filter { $0 <= now }.max()
        nextReviewAt = cards.compactMap(\.nextReviewAt).filter { $0 > now }.min()
    }

    func scheduledCount(on date: Date, calendar: Calendar = .current) -> Int {
        guard !isLocked else { return 0 }
        return cards.filter {
            guard $0.reviewCount > 0, let due = $0.nextReviewAt else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }.count
    }
}

@MainActor
struct StudyProgressSummary {
    let decks: [DeckProgressSummary]

    init(decks: [StudyDeck], isSubscribed: Bool, now: Date, calendar: Calendar = .current) {
        self.decks = decks.filter { $0.parentDeck == nil && !$0.needsDeletion }.map {
            DeckProgressSummary(deck: $0, isSubscribed: isSubscribed, now: now, calendar: calendar)
        }
    }

    var totalCards: Int { decks.reduce(0) { $0 + $1.totalCount } }
    var newCards: Int { decks.reduce(0) { $0 + $1.newCount } }
    var learningCards: Int { decks.reduce(0) { $0 + $1.learningCount } }
    var confirmedCards: Int { decks.reduce(0) { $0 + $1.confirmedCount } }
    var dueCards: Int { decks.reduce(0) { $0 + $1.dueCount } }
    var studiedToday: Int { decks.reduce(0) { $0 + $1.studiedTodayCount } }
    var activeSessions: Int { decks.filter { !$0.isLocked && $0.hasActiveSession }.count }

    var recommended: DeckProgressSummary? {
        let available = decks.filter { !$0.isLocked && $0.totalCount > 0 }
        return available.first { $0.hasActiveSession }
            ?? available.filter { $0.dueCount > 0 }.max { $0.dueCount < $1.dueCount }
            ?? available.first { $0.learningCount > 0 || $0.newCount > 0 }
    }
}
