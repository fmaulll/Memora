import Foundation

final class CardAPI {

    static let shared = CardAPI()

    private init() {}

    // MARK: - Create One

    func create(
        id: UUID,
        deckID: UUID,
        front: String,
        back: String,
        frontImageURL: String? = nil,
        backImageURL: String? = nil
    ) async throws -> CardResponse {

        let request = CardCreateRequest(
            id: id,
            front: front,
            back: back,
            frontImageURL: frontImageURL,
            backImageURL: backImageURL
        )

        return try await APIClient.shared.request(
            endpoint: "/decks/\(deckID)/cards",
            method: .post,
            body: request
        )
    }


    // MARK: - Create Multiple

    func createBulk(
        deckID: UUID,
        cards: [CardCreateRequest]
    ) async throws -> [CardResponse] {

        let request = BulkCardCreateRequest(
            cards: cards
        )

        return try await APIClient.shared.request(
            endpoint: "/decks/\(deckID)/cards/bulk",
            method: .post,
            body: request
        )
    }


    // MARK: - Get All

    func getAll(
        deckID: UUID
    ) async throws -> [CardResponse] {

        return try await APIClient.shared.request(
            endpoint: "/decks/\(deckID)/cards",
            method: .get
        )
    }


    // MARK: - Get One

    func get(
        id: UUID
    ) async throws -> CardResponse {

        return try await APIClient.shared.request(
            endpoint: "/cards/\(id)",
            method: .get
        )
    }


    // MARK: - Update

    func update(
        cardID: UUID,
        front: String? = nil,
        back: String? = nil,
        frontImageURL: String? = nil,
        backImageURL: String? = nil
    ) async throws -> CardResponse {

        let request = CardUpdateRequest(
            front: front,
            back: back,
            frontImageURL: frontImageURL,
            backImageURL: backImageURL
        )

        return try await APIClient.shared.request(
            endpoint: "/cards/\(cardID)",
            method: .put,
            body: request
        )
    }


    // MARK: - Delete

    func delete(
        cardID: UUID
    ) async throws {

        try await APIClient.shared.requestWithoutResponse(
            endpoint: "/cards/\(cardID)",
            method: .delete
        )
    }
}