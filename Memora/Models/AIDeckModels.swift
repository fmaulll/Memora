import Foundation

// MARK: - Plan Request

struct DeckPlanRequest: Encodable {
    let topic: String
    let educationLevel: String
    let studyGoal: String
    let learningDepth: String

    enum CodingKeys: String, CodingKey {
        case topic
        case educationLevel = "education_level"
        case studyGoal = "study_goal"
        case learningDepth = "learning_depth"
    }
}

// MARK: - Plan Response

struct DeckPlanResponse: Codable {
    let title: String
    let subject: String
    let educationLevel: String
    let chapters: [ChapterPlan]

    enum CodingKeys: String, CodingKey {
        case title
        case subject
        case educationLevel = "education_level"
        case chapters
    }
}

struct ChapterPlan: Codable, Identifiable {
    let title: String
    let description: String
    let keyConcepts: [String]
    let cardCount: Int

    var id: String {
        title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case keyConcepts = "key_concepts"
        case cardCount = "card_count"
    }
}

// MARK: - Generated Deck

struct GeneratedDeckResponse: Decodable {
    let title: String
    let subject: String
    let educationLevel: String
    let chapters: [GeneratedChapter]

    enum CodingKeys: String, CodingKey {
        case title
        case subject
        case educationLevel = "education_level"
        case chapters
    }
}

struct GeneratedChapter: Decodable, Identifiable {
    let title: String
    let cards: [GeneratedCard]

    var id: String {
        title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case cards
    }
}

struct GeneratedCard: Decodable, Identifiable {
    let front: String
    let back: String

    var id: String {
        front
    }
}