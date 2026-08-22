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

        deck.isSynced = true

        for card in deck.cards {
            card.isSynced = true
        }
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

        let serverDeckIDs = Set(
            serverDecks.map { $0.id }
        )

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
                deck = localDeck

                deck.title = serverDeck.title
                deck.subject = serverDeck.subject
                deck.educationLevel = serverDeck.educationLevel
                deck.isFavorite = serverDeck.isFavorite
                deck.isSynced = true
            } else {
                // New server deck → create locally
                deck = StudyDeck(
                    id: serverDeck.id,
                    title: serverDeck.title,
                    subject: serverDeck.subject,
                    educationLevel: serverDeck.educationLevel
                )

                deck.isFavorite = serverDeck.isFavorite
                deck.isSynced = true

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
                    localCard.front = serverCard.front
                    localCard.back = serverCard.back
                    localCard.isSynced = true
                } else {

                    // INSERT
                    let newCard = StudyFlashcardCard(
                        id: serverCard.id,
                        front: serverCard.front,
                        back: serverCard.back
                    )

                    newCard.isSynced = true

                    deck.cards.append(newCard)
                }
            }

            // DELETE cards removed from server
            deck.cards.removeAll { card in
                !incomingIDs.contains(card.id) && card.isSynced
            }
        }

        // Delete locally synced decks that no longer exist on server
        let localDecks = try modelContext.fetch(
            FetchDescriptor<StudyDeck>()
        )

        for localDeck in localDecks {
            if localDeck.isSynced &&
            !serverDeckIDs.contains(localDeck.id) {

                modelContext.delete(localDeck)
            }
        }

        try modelContext.save()

        print("DOWNLOAD SYNC SUCCESS")
    }

    func uploadUnsyncedDecks(
        modelContext: ModelContext
    ) async throws {

        let descriptor = FetchDescriptor<StudyDeck>(
            predicate: #Predicate<StudyDeck> { deck in
                deck.isSynced == false
            }
        )

        let unsyncedDecks = try modelContext.fetch(descriptor)

        print("UNSYNCED DECKS:", unsyncedDecks.count)

        for deck in unsyncedDecks {

            print("UPLOADING DECK:", deck.id, deck.title)

            do {

                let serverDeck = try await DeckAPI.shared.create(
                    id: deck.id,
                    title: deck.title,
                    subject: deck.subject,
                    educationLevel: deck.educationLevel,
                    isFavorite: deck.isFavorite
                )

                // Verify the server kept the same UUID
                guard serverDeck.id == deck.id else {
                    print("❌ UUID MISMATCH")
                    print("LOCAL:", deck.id)
                    print("SERVER:", serverDeck.id)

                    continue
                }

                deck.isSynced = true

                print("✅ DECK UPLOADED:", deck.id)

            } catch {

                print(
                    "❌ FAILED TO UPLOAD DECK:",
                    deck.id,
                    error
                )

                // Don't mark it synced.
                // It will be retried next time.
            }
        }

        try modelContext.save()

        print("DECK UPLOAD SYNC SUCCESS")
    }

    func uploadUnsyncedCards(
        modelContext: ModelContext
    ) async throws {

        let descriptor = FetchDescriptor<StudyFlashcardCard>(
            predicate: #Predicate<StudyFlashcardCard> { card in
                card.isSynced == false
            }
        )

        let unsyncedCards = try modelContext.fetch(descriptor)

        print("UNSYNCED CARDS:", unsyncedCards.count)

        // Group cards by deck
        let cardsByDeck = Dictionary(
            grouping: unsyncedCards
        ) { card in
            card.deck?.id
        }

        for (deckID, cards) in cardsByDeck {

            guard let deckID else {
                print("❌ CARD GROUP HAS NO DECK")
                continue
            }

            print("")
            print("UPLOADING CARDS FOR DECK:", deckID)
            print("CARD COUNT:", cards.count)

            let requests = cards.map { card in

                CardCreateRequest(
                    id: card.id,
                    front: card.front,
                    back: card.back,
                    frontImageURL: nil,
                    backImageURL: nil
                )
            }

            do {

                let serverCards = try await CardAPI.shared.createBulk(
                    deckID: deckID,
                    cards: requests
                )

                print(
                    "SERVER RETURNED:",
                    serverCards.count,
                    "CARDS"
                )

                // Make sure every local card was returned
                let serverIDs = Set(
                    serverCards.map { $0.id }
                )

                for card in cards {

                    guard serverIDs.contains(card.id) else {
                        print(
                            "❌ SERVER DID NOT RETURN CARD:",
                            card.id
                        )

                        continue
                    }

                    card.isSynced = true

                    print(
                        "✅ CARD UPLOADED:",
                        card.id
                    )
                }

            } catch {

                print(
                    "❌ FAILED TO UPLOAD CARDS FOR DECK:",
                    deckID,
                    error
                )
            }
        }

        try modelContext.save()

        print("")
        print("CARD UPLOAD SYNC SUCCESS")
    }

}