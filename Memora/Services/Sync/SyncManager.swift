import Foundation
import SwiftData

@MainActor
final class SyncManager {


    static let shared = SyncManager()

    private init() {}

    enum CardSyncState {
        static let synced = 0
        static let created = 1
        static let updated = 2
        static let deleted = 3
    }

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
            if card.syncState == CardSyncState.created {
                // Let uploadUnsyncedCards() handle newly created cards
                continue
            }

            if card.syncState == CardSyncState.updated {
                // Let uploadUpdatedCards() handle updates
                continue
            }

            if card.syncState == CardSyncState.deleted {
                // Let uploadDeletedCards() handle deletions
                continue
            }

            card.isSynced = true
            card.syncState = CardSyncState.synced
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
                    localCard.syncState = SyncManager.CardSyncState.synced
                    localCard.needsDeletion = false
                } else {

                    // INSERT
                    let newCard = StudyFlashcardCard(
                        id: serverCard.id,
                        front: serverCard.front,
                        back: serverCard.back
                    )

                    newCard.isSynced = true
                    newCard.syncState = SyncManager.CardSyncState.synced
                    newCard.needsDeletion = false

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

    // MARK: - Upload Unsynced Decks

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

    // MARK: - Upload Unsynced Cards

    func uploadUnsyncedCards(
        modelContext: ModelContext
    ) async throws {

        let descriptor = FetchDescriptor<StudyFlashcardCard>(
            predicate: #Predicate<StudyFlashcardCard> { card in
                card.syncState == 1
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
                    card.syncState = SyncManager.CardSyncState.synced

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

    // MARK: - Upload Updated Cards

    func uploadUpdatedCards(
        modelContext: ModelContext
    ) async throws {

        let descriptor = FetchDescriptor<StudyFlashcardCard>(
            predicate: #Predicate<StudyFlashcardCard> { card in
                card.syncState == 2
            }
        )

        let unsyncedCards = try modelContext.fetch(descriptor)

        print("UNSYNCED CARDS FOR UPDATE:", unsyncedCards.count)

        for card in unsyncedCards {

            guard let deck = card.deck else {
                print("❌ CARD HAS NO DECK:", card.id)
                continue
            }

            print("")
            print("UPDATING CARD:", card.id)
            print("DECK:", deck.id)
            print("FRONT:", card.front)
            print("BACK:", card.back)

            do {

                let serverCard = try await CardAPI.shared.update(
                    cardID: card.id,
                    front: card.front,
                    back: card.back,
                    frontImageURL: nil,
                    backImageURL: nil
                )

                guard serverCard.id == card.id else {

                    print("❌ UUID MISMATCH")
                    print("LOCAL:", card.id)
                    print("SERVER:", serverCard.id)

                    continue
                }

                card.isSynced = true
                card.syncState = SyncManager.CardSyncState.synced

                print(
                    "✅ CARD UPDATED:",
                    card.id
                )

            } catch {

                print(
                    "❌ FAILED TO UPDATE CARD:",
                    card.id,
                    error
                )
            }
        }

        try modelContext.save()

        print("")
        print("CARD UPDATE SYNC SUCCESS")
    }

    // MARK: - Upload Deleted Cards

    func uploadDeletedCards(
        modelContext: ModelContext
    ) async throws {

        let descriptor = FetchDescriptor<StudyFlashcardCard>(
            predicate: #Predicate<StudyFlashcardCard> { card in
                card.syncState == 3 &&
                card.needsDeletion == true
            }
        )

        let deletedCards = try modelContext.fetch(descriptor)

        print("DELETED CARDS TO UPLOAD:", deletedCards.count)

        for card in deletedCards {

            print("")
            print("DELETING CARD:", card.id)

            do {

                try await CardAPI.shared.delete(
                    cardID: card.id
                )

                print(
                    "✅ SERVER DELETE SUCCESS:",
                    card.id
                )

                // Server successfully deleted it.
                // Now remove the local copy.
                modelContext.delete(card)

            } catch {

                print(
                    "❌ FAILED TO DELETE CARD:",
                    card.id,
                    error
                )

                // Keep it locally with isDeleted = true.
                // It can be retried during the next sync.
            }
        }

        try modelContext.save()

        print("")
        print("CARD DELETE SYNC SUCCESS")
    }

    // MARK: - Full Sync

    func sync(
        modelContext: ModelContext
    ) async throws {

        print("")
        print("========== SYNC START ==========")

        // 1. Upload newly created decks
        print("")
        print("STEP 1: UPLOAD DECKS")

        try await uploadUnsyncedDecks(
            modelContext: modelContext
        )

        // 2. Upload newly created cards
        print("")
        print("STEP 2: UPLOAD NEW CARDS")

        try await uploadUnsyncedCards(
            modelContext: modelContext
        )

        // 3. Upload updated cards
        print("")
        print("STEP 3: UPLOAD UPDATED CARDS")

        try await uploadUpdatedCards(
            modelContext: modelContext
        )

        // 4. Upload deleted cards
        print("")
        print("STEP 4: UPLOAD DELETED CARDS")

        try await uploadDeletedCards(
            modelContext: modelContext
        )

        // 5. Download server state
        print("")
        print("STEP 5: DOWNLOAD")

        try await downloadAll(
            modelContext: modelContext
        )

        print("")
        print("========== SYNC SUCCESS ==========")
    }

}