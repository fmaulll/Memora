import Foundation
import SwiftData

@Model
final class StudyDeck {
    var title: String
    var subject: String
    var educationLevel: String
    var createdAt: Date
    var isFavorite: Bool = false
    var lastRating: String?

    // MARK: - Persistent Study Session

    var studyQueueIDs: [UUID] = []
    var learningQueueIDs: [UUID] = []
    var studyCompletedCount: Int = 0
    var isStudySessionActive: Bool = false

    // MARK: - Cards

    @Relationship(
        deleteRule: .cascade,
        inverse: \StudyFlashcardCard.deck
    )
    var cards: [StudyFlashcardCard]

    init(
        title: String,
        subject: String,
        educationLevel: String,
        createdAt: Date = .now,
        cards: [StudyFlashcardCard] = []
    ) {
        self.title = title
        self.subject = subject
        self.educationLevel = educationLevel
        self.createdAt = createdAt
        self.cards = cards
    }
}

@Model
final class StudyFlashcardCard {
    var id: UUID
    var front: String
    var back: String

    var frontImageData: Data?
    var backImageData: Data?

    // MARK: - Study Progress

    var reviewCount: Int = 0
    var correctCount: Int = 0

    var lastReviewedAt: Date?
    var nextReviewAt: Date?

    var difficulty: Double = 0.0

    var interval: Int = 0

    var deck: StudyDeck?

    init(
        front: String,
        back: String,
        frontImageData: Data? = nil,
        backImageData: Data? = nil
    ) {

        self.id = UUID()

        self.front = front
        self.back = back
        self.frontImageData = frontImageData
        self.backImageData = backImageData
    }
}