import Foundation

final class DeckAPI {

    static let shared = DeckAPI()

    private init() {}

    // MARK: - Create

    func create(
        id: UUID,
        title: String,
        subject: String,
        educationLevel: String,
        learningLanguage: String? = nil,
        isFavorite: Bool = false,
        parentDeckId: UUID? = nil
    ) async throws -> DeckResponse {

        let request = DeckCreateRequest(
            id: id,
            title: title,
            subject: subject,
            educationLevel: educationLevel,
            learningLanguage: learningLanguage,
            isFavorite: isFavorite,
            parentDeckId: parentDeckId
        )

        return try await APIClient.shared.request(
            endpoint: "/decks",
            method: .post,
            body: request
        )
    }

    // MARK: - Get All

    func getAll() async throws -> [DeckResponse] {

        return try await APIClient.shared.request(
            endpoint: "/decks",
            method: .get
        )
    }

    // MARK: - Get One

    func get(
        id: UUID
    ) async throws -> DeckResponse {

        return try await APIClient.shared.request(
            endpoint: "/decks/\(id)",
            method: .get
        )
    }

    // MARK: - Update

    func update(
        id: UUID,
        title: String? = nil,
        subject: String? = nil,
        educationLevel: String? = nil,
        isFavorite: Bool? = nil,
        parentDeckId: UUID? = nil
    ) async throws -> DeckResponse {

        let request = DeckUpdateRequest(
            title: title,
            subject: subject,
            educationLevel: educationLevel,
            isFavorite: isFavorite,
            parentDeckId: parentDeckId
        )

        return try await APIClient.shared.request(
            endpoint: "/decks/\(id)",
            method: .put,
            body: request
        )
    }

    // MARK: - Delete

    func delete(
        id: UUID
    ) async throws {

        try await APIClient.shared.requestWithoutResponse(
            endpoint: "/decks/\(id)",
            method: .delete
        )
    }
}