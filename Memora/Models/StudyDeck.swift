import Foundation
import SwiftData

@Model
final class StudyDeck {
    var id: UUID

    var isAIGenerated: Bool = false
    var position: Int = 0

    var title: String
    var subject: String
    var educationLevel: String
    var createdAt: Date
    var isFavorite: Bool = false
    var learningLanguage: String?
    var lastRating: String?

    // MARK: - Generation
    var generationStatus: String = "completed"

    // Persist the first-deck gate across launches, including its chapters.
    var requiresSubscription: Bool = false

    var needsSubscription: Bool {
        requiresSubscription || parentDeck?.needsSubscription == true
    }

    var studyQueueIDs: [UUID] = []
    var learningQueueIDs: [UUID] = []
    var studyConfirmationIDs: [UUID] = []
    var studyCompletedCount: Int = 0
    var isStudySessionActive: Bool = false

    // MARK: - Study All Session

    var studyAllQueueIDs: [UUID] = []

    var studyAllLearningQueueIDs: [UUID] = []
    var studyAllConfirmationIDs: [UUID] = []

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
        position: Int = 0
    ) {
        self.id = id
        self.position = position
        self.title = title
        self.subject = subject
        self.educationLevel = educationLevel
        self.createdAt = createdAt

        self.cards = cards
        self.parentDeck = parentDeck
        self.generationStatus = generationStatus

        for card in cards {
            card.deck = self
        }
    }
}

extension StudyDeck {
    static func chapterOrder(_ lhs: StudyDeck, _ rhs: StudyDeck) -> Bool {
        if lhs.position != rhs.position { return lhs.position < rhs.position }
        return lhs.id.uuidString < rhs.id.uuidString
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
    // Revision owned by the persisted backend study state. It prevents an old
    // device from silently overwriting a newer review.
    var studyStateRevision: Int = 0

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
