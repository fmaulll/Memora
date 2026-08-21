import Foundation

struct CardResponse: Decodable {
    let id: UUID
    let deckId: UUID
    let front: String
    let back: String
    let frontImageURL: String?
    let backImageURL: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case deckId = "deck_id"
        case front
        case back
        case frontImageURL = "front_image_url"
        case backImageURL = "back_image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}


struct CardCreateRequest: Encodable {
    let id: UUID
    let front: String
    let back: String
    let frontImageURL: String?
    let backImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case front
        case back
        case frontImageURL = "front_image_url"
        case backImageURL = "back_image_url"
    }
}

struct BulkCardCreateRequest: Encodable {
    let cards: [CardCreateRequest]
}


struct CardUpdateRequest: Encodable {
    let front: String?
    let back: String?
    let frontImageURL: String?
    let backImageURL: String?

    enum CodingKeys: String, CodingKey {
        case front
        case back
        case frontImageURL = "front_image_url"
        case backImageURL = "back_image_url"
    }
}