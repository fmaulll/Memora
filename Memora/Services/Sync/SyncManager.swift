import Foundation
import SwiftData

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

    // MARK: - Download All Decks and Cards

    // MARK: - Download All

    func downloadAll(
        modelContext: ModelContext
    ) async throws {

        let serverDecks = try await DeckAPI.shared.getAll()

        for serverDeck in serverDecks {

            // Find existing local deck
            let serverDeckID = serverDeck.id

            let descriptor = FetchDescriptor<StudyDeck>(
                predicate: #Predicate<StudyDeck> { deck in
                    deck.id == serverDeckID
                }
            )

            let localDeck = try modelContext.fetch(descriptor).first

            let deck: StudyDeck

            if let localDeck {
                // Existing local deck → update
                deck = localDeck

                deck.title = serverDeck.title
                deck.subject = serverDeck.subject
                deck.educationLevel = serverDeck.educationLevel
                deck.isFavorite = serverDeck.isFavorite

            } else {
                // New server deck → create locally
                deck = StudyDeck(
                    id: serverDeck.id,
                    title: serverDeck.title,
                    subject: serverDeck.subject,
                    educationLevel: serverDeck.educationLevel
                )

                deck.isFavorite = serverDeck.isFavorite

                modelContext.insert(deck)
            }

            // Download cards
            let serverCards = try await CardAPI.shared.getAll(
                deckID: serverDeck.id
            )

            // Existing local cards
            let existingCards = deck.cards

            let existingByID = Dictionary(
                uniqueKeysWithValues: existingCards.map {
                    ($0.id, $0)
                }
            )

            var incomingIDs = Set<UUID>()

            for serverCard in serverCards {

                incomingIDs.insert(serverCard.id)

                if let localCard = existingByID[serverCard.id] {

                    // UPDATE
                    localCard.front = serverCard.front
                    localCard.back = serverCard.back

                } else {

                    // INSERT
                    let newCard = StudyFlashcardCard(
                        id: serverCard.id,
                        front: serverCard.front,
                        back: serverCard.back
                    )

                    deck.cards.append(newCard)
                }
            }

            // DELETE cards removed from server
            deck.cards.removeAll {
                !incomingIDs.contains($0.id)
            }
        }

        try modelContext.save()

        print("DOWNLOAD SYNC SUCCESS")
    }


}