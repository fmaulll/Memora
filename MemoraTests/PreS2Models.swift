import Foundation
import SwiftData

// Frozen pre-S2 persisted model definitions. Keep property names, defaults,
// relationships and attributes unchanged: this creates real legacy disk stores.
// Nested types retain the original SwiftData entity names.
enum PreS2Models {
    @Model
    final class StudyDeck {
        var id: UUID

        var title: String
        var subject: String
        var educationLevel: String
        var createdAt: Date
        var isFavorite: Bool = false
        var learningLanguage: String?
        var lastRating: String?

        // MARK: - Generation
        var generationStatus: String = "completed"

        var position: Int?

        // Persist the first-deck gate across launches, including its chapters.
        var requiresSubscription: Bool = false

        var needsSubscription: Bool {
            requiresSubscription || parentDeck?.needsSubscription == true
        }

        var studyQueueIDs: [UUID] = []
        var learningQueueIDs: [UUID] = []
        var studyCompletedCount: Int = 0
        var isStudySessionActive: Bool = false

        var studyAllBatchCardIDs: [UUID] = []

        var studyBatchCardIDs: [UUID] = []

        // MARK: - Study All Session

        var studyAllQueueIDs: [UUID] = []

        var studyAllLearningQueueIDs: [UUID] = []

        var studyAllCompletedCount: Int = 0

        var isStudyAllSessionActive: Bool = false

        // MARK: - Deck Hierarchy

        @Relationship(
            inverse: \StudyDeck.parentDeck
        )
        var childDecks: [StudyDeck] = []

        var parentDeck: StudyDeck?

        // MARK: - Cards

        @Relationship(
            deleteRule: .cascade,
            inverse: \StudyFlashcardCard.deck
        )
        var cards: [StudyFlashcardCard]

        var totalCardCount: Int {
            cards.count + childDecks.reduce(0) {
                $0 + $1.cards.count
            }
        }

        var isSynced: Bool = false
        var needsDeletion: Bool = false
        
        init(
            id: UUID = UUID(),
            title: String,
            subject: String,
            educationLevel: String,
            learningLanguage: String? = "English",
            createdAt: Date = .now,
            cards: [StudyFlashcardCard] = [],
            parentDeck: StudyDeck? = nil,
            generationStatus: String = "completed",
            position: Int? = nil
        ) {
            self.id = id
            self.title = title
            self.subject = subject
            self.educationLevel = educationLevel
            self.createdAt = createdAt

            self.cards = cards
            self.parentDeck = parentDeck
            self.generationStatus = generationStatus
            self.position = position

            for card in cards {
                card.deck = self
            }
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

        var isSynced: Bool = false
        var needsDeletion: Bool = false
        var syncState: Int = 0

        init(
            id: UUID = UUID(),
            front: String,
            back: String,
            frontImageData: Data? = nil,
            backImageData: Data? = nil,
            deck: StudyDeck? = nil
        ) {
            self.id = id
            self.front = front
            self.back = back
            self.frontImageData = frontImageData
            self.backImageData = backImageData
            self.deck = deck

            // self.isSynced = false
            // self.isDeleted = false
        }
    }

    @Model
    final class LocalUserProfile {

        @Attribute(.unique)
        var id: UUID

        // Backend user ID.
        // nil means this is still a guest.
        var userId: UUID?

        var name: String

        var email: String?

        var educationLevel: String?

        var studyReason: String?

        var createdAt: Date

        init(
            id: UUID = UUID(),
            userId: UUID? = nil,
            name: String,
            email: String? = nil,
            educationLevel: String? = nil,
            studyReason: String? = nil,
            createdAt: Date = Date()
        ) {
            self.id = id
            self.userId = userId
            self.name = name
            self.email = email
            self.educationLevel = educationLevel
            self.studyReason = studyReason
            self.createdAt = createdAt
        }
    }

    @Model
    final class Item {
        var timestamp: Date
        
        init(timestamp: Date) {
            self.timestamp = timestamp
        }
    }
}
