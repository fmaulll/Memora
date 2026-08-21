import Foundation

@MainActor
final class SyncManager {

    static let shared = SyncManager()

    private init() {}

    // MARK: - Sync Deck

    func syncDeck(_ deck: StudyDeck) async throws {

        let exists = try await deckExists(deck.id)

        if exists {
            try await updateDeck(deck)
        } else {
            try await createDeck(deck)
        }

        try await syncCards(
            deck.cards,
            deckID: deck.id
        )
    }

    // MARK: - Create Deck

    private func createDeck(
        _ deck: StudyDeck
    ) async throws {

        let response = try await DeckAPI.shared.create(
            id: deck.id,
            title: deck.title,
            subject: deck.subject,
            educationLevel: deck.educationLevel,
            isFavorite: deck.isFavorite
        )

        print("Created deck:", response.id)
    }

    // MARK: - Update Deck

    private func updateDeck(
        _ deck: StudyDeck
    ) async throws {

        let response = try await DeckAPI.shared.update(
            id: deck.id,
            title: deck.title,
            subject: deck.subject,
            educationLevel: deck.educationLevel,
            isFavorite: deck.isFavorite
        )

        print("Updated deck:", response.id)
    }

    // MARK: - Check Deck

    private func deckExists(
        _ id: UUID
    ) async throws -> Bool {

        do {
            _ = try await DeckAPI.shared.get(id: id)
            return true

        } catch APIError.httpError(let statusCode, _) {

            if statusCode == 404 {
                return false
            }

            throw APIError.httpError(
                statusCode: statusCode,
                message: nil
            )
        }
    }

    // MARK: - Sync Cards

    private func syncCards(
        _ cards: [StudyFlashcardCard],
        deckID: UUID
    ) async throws {

        let requests = cards.map { card in

            CardCreateRequest(
                id: card.id,
                front: card.front,
                back: card.back,
                frontImageURL: nil,
                backImageURL: nil
            )
        }

        let response = try await CardAPI.shared.createBulk(
            deckID: deckID,
            cards: requests
        )

        print("Synced cards:", response.count)
    }
}