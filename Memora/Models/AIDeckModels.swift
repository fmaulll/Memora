import Foundation

// MARK: - Plan Request

struct DeckPlanRequest: Encodable {
    let topic: String
    let educationLevel: String
    let studyPurpose: String
    let preparationDetails: String
    let targetDate: String?
    let studyMaterialIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case topic
        case educationLevel = "education_level"
        case studyPurpose = "study_purpose"
        case preparationDetails = "preparation_details"
        case targetDate = "target_date"
        case studyMaterialIDs = "study_material_ids"
    }
}

// MARK: - Study Materials

struct StudyMaterialsUploadResponse: Decodable {
    let materials: [UploadedStudyMaterial]
}

struct UploadedStudyMaterial: Decodable, Identifiable {
    let id: String
    let filename: String
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
    let id: UUID
    let title: String
    let subject: String
    let educationLevel: String
    let generationStatus: String
    let chapters: [GeneratedChapter]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subject
        case educationLevel = "education_level"
        case generationStatus = "generation_status"
        case chapters
    }
}

struct GeneratedChapter: Decodable, Identifiable {
    let id: UUID
    let title: String
    let generationStatus: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case generationStatus = "generation_status"
    }
}

// MARK: - Generated Deck

struct GeneratedCard: Decodable {
    let front: String
    let back: String
}

struct GenerateDeckRequest: Encodable {
    let plan: DeckPlanResponse
    let studyPurpose: String
    let targetDate: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case studyPurpose = "study_purpose"
        case targetDate = "target_date"
    }
}

struct StudyDayResponse: Decodable {
    let day: Int
    let date: String
    let newCards: Int
    let focus: String

    enum CodingKeys: String, CodingKey {
        case day
        case date
        case newCards = "new_cards"
        case focus
    }
}


struct StudyTimelineResponse: Decodable {
    let totalDays: Int
    let totalCards: Int
    let dailyPlan: [StudyDayResponse]

    enum CodingKeys: String, CodingKey {
        case totalDays = "total_days"
        case totalCards = "total_cards"
        case dailyPlan = "daily_plan"
    }
}


struct GeneratedDeckWithTimelineResponse: Decodable {
    let deck: GeneratedDeckResponse
    let timeline: StudyTimelineResponse?
}

// MARK: - Generation Status

struct DeckGenerationStatusResponse: Decodable {
    let deckID: UUID
    let generationStatus: String
    let chapters: [ChapterGenerationStatus]

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id"
        case generationStatus = "generation_status"
        case chapters
    }
}


struct ChapterGenerationStatus: Decodable, Identifiable {
    let id: UUID
    let title: String
    let generationStatus: String
    let cardCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case generationStatus = "generation_status"
        case cardCount = "card_count"
    }
}