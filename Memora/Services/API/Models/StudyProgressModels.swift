import Foundation

// These are server facts and upload contracts, not the local study queues.
struct StudyProgressResponse: Codable {
    let deckID: UUID
    let decks: [DeckLearningFacts]
    let summary: StudyProgressSummary

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id", decks, summary
    }
}

struct DeckLearningFacts: Codable {
    let deckID: UUID
    let progressEpoch: UUID
    let title: String
    let parentDeckID: UUID?
    let position: Int
    let generationStatus: String
    let cards: [CardLearningFact]
    let learnedCardCount: Int
    let totalCardCount: Int
    let completionPercentage: Double
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id", progressEpoch = "progress_epoch", title
        case parentDeckID = "parent_deck_id", position, generationStatus = "generation_status"
        case cards, learnedCardCount = "learned_card_count", totalCardCount = "total_card_count"
        case completionPercentage = "completion_percentage", completed
    }
}

struct CardLearningFact: Codable {
    let cardID: UUID
    let learnedAt: Date?

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id", learnedAt = "learned_at"
    }
}

struct StudyProgressSummary: Codable {
    let totalDeckCount: Int
    let completedDeckCount: Int
    let learnedCardCount: Int
    let totalCardCount: Int

    enum CodingKeys: String, CodingKey {
        case totalDeckCount = "total_deck_count", completedDeckCount = "completed_deck_count"
        case learnedCardCount = "learned_card_count", totalCardCount = "total_card_count"
    }
}

struct DeckProgressEpoch: Codable, Equatable {
    let deckID: UUID
    let progressEpoch: UUID

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id", progressEpoch = "progress_epoch"
    }
}

struct LearnedCardTransition: Codable, Equatable {
    enum Phase: String, Codable { case review }
    enum Answer: String, Codable { case gotIt = "got_it" }

    let cardID: UUID
    let phase: Phase
    let answer: Answer

    init(cardID: UUID) {
        self.cardID = cardID
        phase = .review
        answer = .gotIt
    }

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id", phase, answer
    }
}

struct DeckLearnedTransitions: Codable, Equatable {
    let deckID: UUID
    let progressEpoch: UUID
    let learnedCards: [LearnedCardTransition]

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id", progressEpoch = "progress_epoch", learnedCards = "learned_cards"
    }
}

struct StudyProgressSubmission: Codable, Equatable {
    // Backend calls this session_id, but it identifies one immutable upload.
    // The caller must persist it and reuse the entire payload on retry.
    let sessionID: UUID
    let completedAt: Date
    let decks: [DeckLearnedTransitions]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", completedAt = "completed_at", decks
    }
}

struct StudyProgressSubmissionResponse: Codable {
    let sessionID: UUID
    let completedAt: Date
    let submittedAt: Date
    let decks: [DeckSubmissionResult]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id", completedAt = "completed_at", submittedAt = "submitted_at", decks
    }
}

struct DeckSubmissionResult: Codable {
    let deckID: UUID
    let progressEpoch: UUID
    let acceptedCardIDs: [UUID]
    let alreadyLearnedCardIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id", progressEpoch = "progress_epoch"
        case acceptedCardIDs = "accepted_card_ids", alreadyLearnedCardIDs = "already_learned_card_ids"
    }
}

struct StudyProgressResetRequest: Codable, Equatable {
    let resetID: UUID
    let expectedDecks: [DeckProgressEpoch]

    enum CodingKeys: String, CodingKey {
        case resetID = "reset_id", expectedDecks = "expected_decks"
    }
}

struct StudyProgressResetResponse: Codable {
    let resetID: UUID
    let deckID: UUID
    let resetAt: Date
    let decks: [DeckResetResult]

    enum CodingKeys: String, CodingKey {
        case resetID = "reset_id", deckID = "deck_id", resetAt = "reset_at", decks
    }
}

struct DeckResetResult: Codable {
    let deckID: UUID
    let progressEpoch: UUID
    let previousEpoch: UUID
    let clearedCardCount: Int

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id", progressEpoch = "progress_epoch"
        case previousEpoch = "previous_epoch", clearedCardCount = "cleared_card_count"
    }
}
