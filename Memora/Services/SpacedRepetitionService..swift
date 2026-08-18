import Foundation

struct SpacedRepetitionService {

    func review(
        card: StudyFlashcardCard,
        rating: CardRating
    ) {
        let now = Date()

        card.reviewCount += 1
        card.lastReviewedAt = now

        switch rating {

        case .again:
            card.interval = 0
            card.nextReviewAt = Calendar.current.date(
                byAdding: .minute,
                value: 10,
                to: now
            )

        case .hard:
            let newInterval = max(
                1,
                Int(Double(max(card.interval, 1)) * 1.2)
            )

            card.interval = newInterval
            card.nextReviewAt = Calendar.current.date(
                byAdding: .day,
                value: newInterval,
                to: now
            )

        case .good:
            card.correctCount += 1

            let newInterval = max(
                1,
                Int(Double(max(card.interval, 1)) * 2.5)
            )

            card.interval = newInterval
            card.nextReviewAt = Calendar.current.date(
                byAdding: .day,
                value: newInterval,
                to: now
            )

        case .easy:
            card.correctCount += 1

            let newInterval = max(
                2,
                Int(Double(max(card.interval, 1)) * 4.0)
            )

            card.interval = newInterval
            card.nextReviewAt = Calendar.current.date(
                byAdding: .day,
                value: newInterval,
                to: now
            )
        }
    }
}
