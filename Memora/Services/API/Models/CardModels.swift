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

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        deckId = try values.decode(UUID.self, forKey: .deckId)
        front = try values.decode(String.self, forKey: .front)
        back = try values.decode(String.self, forKey: .back)
        frontImageURL = try values.decodeIfPresent(String.self, forKey: .frontImageURL)
        backImageURL = try values.decodeIfPresent(String.self, forKey: .backImageURL)
        createdAt = try values.decodeLegacyUTCDate(forKey: .createdAt)
        updatedAt = try values.decodeLegacyUTCDate(forKey: .updatedAt)
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
