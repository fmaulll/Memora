import Foundation

struct SpacedRepetitionService {
    /// Short steps keep unfinished cards due. Only confirmed recall earns a
    /// longer interval; the session queue controls repetition during studying.
    func review(
        card: StudyFlashcardCard,
        rating: CardRating,
        isConfirmed: Bool,
        now: Date = Date()
    ) {
        card.reviewCount += 1
        card.lastReviewedAt = now

        switch rating {
        case .again:
            card.interval = 0
            card.nextReviewAt = now.addingTimeInterval(60)
        case .good:
            guard isConfirmed else {
                card.nextReviewAt = now.addingTimeInterval(10 * 60)
                return
            }
            card.correctCount += 1
            let interval = card.interval == 0
                ? 1
                : max(1, Int(Double(card.interval) * 2.5))
            card.interval = interval
            card.nextReviewAt = Calendar.current.date(byAdding: .day, value: interval, to: now)
        }
    }
}
