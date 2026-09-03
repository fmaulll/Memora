import Foundation

struct DeckResponse: Decodable {
    let id: UUID
    let userId: UUID
    let title: String
    let subject: String
    let educationLevel: String
    let learningLanguage: String?
    let isFavorite: Bool

    let generationStatus: String

    let createdAt: Date
    let updatedAt: Date
    let parentDeckId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case subject
        case educationLevel = "education_level"
        case learningLanguage = "learning_language"
        case isFavorite = "is_favorite"

        case generationStatus = "generation_status"

        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case parentDeckId = "parent_deck_id"
    }
}

struct DeckCreateRequest: Encodable {
    let id: UUID
    let title: String
    let subject: String
    let educationLevel: String
    let learningLanguage: String?
    let isFavorite: Bool
    let parentDeckId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subject
        case educationLevel = "education_level"
        case learningLanguage = "learning_language"
        case isFavorite = "is_favorite"
        case parentDeckId = "parent_deck_id"
    }
}

struct DeckUpdateRequest: Encodable {
    let title: String?
    let subject: String?
    let educationLevel: String?
    let isFavorite: Bool?
    let parentDeckId: UUID?

    enum CodingKeys: String, CodingKey {
        case title
        case subject
        case educationLevel = "education_level"
        case isFavorite = "is_favorite"
        case parentDeckId = "parent_deck_id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encodeIfPresent(
            educationLevel,
            forKey: .educationLevel
        )
        try container.encodeIfPresent(
            isFavorite,
            forKey: .isFavorite
        )

        // IMPORTANT:
        // Encode nil as explicit JSON null.
        try container.encode(
            parentDeckId,
            forKey: .parentDeckId
        )
    }
}
