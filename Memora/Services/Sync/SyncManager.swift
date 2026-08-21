import Foundation
import SwiftData

@MainActor
final class SyncManager {

    static let shared = SyncManager()

    private init() {}

    // MARK: - Sync Deck

    func syncDeck(
        _ deck: StudyDeck
    ) async throws {

        let deckResponse = try await DeckAPI.shared.create(
            id: deck.id,
            title: deck.title,
            subject: deck.subject,
            educationLevel: deck.educationLevel,
            isFavorite: deck.isFavorite
        )

        print("Synced deck:")
        print(deckResponse.id)
        print(deckResponse.title)

        // Sync cards after deck succeeds
        try await syncCards(
            deckID: deck.id,
            cards: deck.cards
        )
    }

    // MARK: - Sync Cards

    private func syncCards(
        deckID: UUID,
        cards: [StudyFlashcardCard]
    ) async throws {

        guard !cards.isEmpty else {
            return
        }

        let requests = cards.map { card in

            CardCreateRequest(
                id: card.id,
                front: card.front,
                back: card.back,
                frontImageURL: nil,
                backImageURL: nil
            )
        }

        let responses = try await CardAPI.shared.createBulk(
            deckID: deckID,
            cards: requests
        )

        print("Synced \(responses.count) cards")
    }
}