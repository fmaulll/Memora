import SwiftUI
import Foundation
import Observation
import SwiftData

struct ContentView: View {
    @State private var isShowingSplash = true
    @State private var authManager = AuthManager.shared

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            if isShowingSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isShowingSplash = false
                    }
                }
            } else {
                if authManager.isAuthenticated {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            guard authManager.isAuthenticated else {
                print("NOT AUTHENTICATED — SKIPPING APP SYNC")
                return
            }

            Task {
                await AppSyncManager.shared.sync(
                    modelContext: modelContext
                )
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated else {
                return
            }

            Task {
                await AppSyncManager.shared.sync(
                    modelContext: modelContext
                )
            }
        }
        .task {
            await authManager.restoreSession(
                modelContext: modelContext
            )
        }

        // Text(
        //     authManager.isAuthenticated
        //         ? "Authenticated"
        //         : "Not authenticated"
        // )

        Button("Add Offline Deck") {
            do {
                let deck = StudyDeck(
                    title: "Offline Card Test",
                    subject: "Testing",
                    educationLevel: "Beginner"
                )

                deck.isSynced = false

                modelContext.insert(deck)

                try modelContext.save()

                print("Created offline deck:")
                print("ID:", deck.id)
                print("Title:", deck.title)
                print("Synced:", deck.isSynced)

            } catch {
                print("OFFLINE DECK ERROR:", error)
            }
        }


        Button("Logout / Clear Token") {
            KeychainService.shared.deleteAccessToken()
        }

        Button("Upload Unsynced Decks") {
            Task {
                do {
                    try await SyncManager.shared.uploadUnsyncedDecks(
                        modelContext: modelContext
                    )

                    print("UPLOAD SUCCESS")

                } catch {
                    print("UPLOAD ERROR:", error)
                }
            }
        }

        // Button("Verify Uploaded Deck") {
        //     Task {
        //         let deckID = UUID(
        //             uuidString: "E6F1F6FE-D07D-4FFA-AE79-1FE39051D719"
        //         )!

        //         do {
        //             // MARK: Server verification

        //             let serverDeck = try await DeckAPI.shared.get(
        //                 id: deckID
        //             )

        //             print("========== SERVER VERIFICATION ==========")
        //             print("SERVER DECK FOUND")
        //             print("ID:", serverDeck.id)
        //             print("TITLE:", serverDeck.title)
        //             print("SUBJECT:", serverDeck.subject)
        //             print("FAVORITE:", serverDeck.isFavorite)

        //             // MARK: Local verification

        //             let descriptor = FetchDescriptor<StudyDeck>(
        //                 predicate: #Predicate<StudyDeck> { deck in
        //                     deck.id == deckID
        //                 }
        //             )

        //             guard let localDeck = try modelContext.fetch(
        //                 descriptor
        //             ).first else {
        //                 print("❌ LOCAL DECK NOT FOUND")
        //                 return
        //             }

        //             print("")
        //             print("========== LOCAL VERIFICATION ==========")
        //             print("LOCAL DECK FOUND")
        //             print("ID:", localDeck.id)
        //             print("TITLE:", localDeck.title)
        //             print("SUBJECT:", localDeck.subject)
        //             print("SYNCED:", localDeck.isSynced)

        //             // MARK: UUID verification

        //             print("")
        //             print("========== UUID VERIFICATION ==========")

        //             print("LOCAL :", localDeck.id)
        //             print("SERVER:", serverDeck.id)

        //             if localDeck.id == serverDeck.id {
        //                 print("✅ UUID MATCH")
        //             } else {
        //                 print("❌ UUID MISMATCH")
        //             }

        //             // MARK: Final result

        //             print("")
        //             print("========== FINAL RESULT ==========")

        //             if localDeck.id == serverDeck.id &&
        //                 localDeck.isSynced {

        //                 print("🎉 DECK SYNC VERIFIED SUCCESSFULLY")

        //             } else {

        //                 print("❌ DECK SYNC VERIFICATION FAILED")
        //             }

        //         } catch {
        //             print("❌ VERIFICATION ERROR:", error)
        //         }
        //     }
        // }

        Button("Test Upload Unsynced Cards") {
            Task {
                do {
                    // Find the test deck
                    let descriptor = FetchDescriptor<StudyDeck>(
                        predicate: #Predicate<StudyDeck> { deck in
                            deck.title == "Offline Card Test"
                        }
                    )

                    guard let deck = try modelContext.fetch(descriptor).first else {
                        print("❌ Offline Card Test deck not found")
                        return
                    }

                    // Create 3 local-only cards
                    let cards = [
                        StudyFlashcardCard(
                            front: "Card A",
                            back: "Answer A"
                        ),
                        StudyFlashcardCard(
                            front: "Card B",
                            back: "Answer B"
                        ),
                        StudyFlashcardCard(
                            front: "Card C",
                            back: "Answer C"
                        )
                    ]

                    for card in cards {
                        card.isSynced = false
                        deck.cards.append(card)

                        print(
                            "Created local card:",
                            card.id,
                            card.front
                        )
                    }

                    try modelContext.save()

                    print("")
                    print("LOCAL CARDS CREATED:", cards.count)
                    print("DECK ID:", deck.id)

                    // Upload them
                    try await SyncManager.shared.uploadUnsyncedCards(
                        modelContext: modelContext
                    )

                    print("")
                    print("🎉 CARD UPLOAD TEST SUCCESS")

                    // Verify local state
                    print("")
                    print("========== LOCAL CARD STATE ==========")

                    for card in cards {
                        print(
                            card.id,
                            "|",
                            card.front,
                            "| synced:",
                            card.isSynced
                        )
                    }

                } catch {
                    print(
                        "❌ CARD UPLOAD TEST ERROR:",
                        error
                    )
                }
            }
        }

        Button("Upload Unsynced Cards") {
            Task {
                do {

                    try await SyncManager.shared.uploadUnsyncedCards(
                        modelContext: modelContext
                    )

                    print("CARD UPLOAD SUCCESS")

                } catch {

                    print(
                        "CARD UPLOAD ERROR:",
                        error
                    )
                }
            }
        }

        Button("Verify Uploaded Cards") {
            Task {
                do {

                    let deckID = UUID(
                        uuidString: "E11BA336-B22E-42A2-822B-EDC7938B7D5C"
                    )!

                    // MARK: Server

                    let serverCards = try await CardAPI.shared.getAll(
                        deckID: deckID
                    )

                    print("")
                    print("========== SERVER CARDS ==========")
                    print("SERVER CARD COUNT:", serverCards.count)

                    for card in serverCards {
                        print(
                            "SERVER:",
                            card.id,
                            "|",
                            card.front
                        )
                    }

                    // MARK: Local

                    let descriptor = FetchDescriptor<StudyDeck>(
                        predicate: #Predicate<StudyDeck> { deck in
                            deck.id == deckID
                        }
                    )

                    guard let localDeck = try modelContext.fetch(
                        descriptor
                    ).first else {
                        print("❌ LOCAL DECK NOT FOUND")
                        return
                    }

                    print("")
                    print("========== LOCAL CARDS ==========")
                    print("LOCAL CARD COUNT:", localDeck.cards.count)

                    for card in localDeck.cards {
                        print(
                            "LOCAL:",
                            card.id,
                            "|",
                            card.front,
                            "| synced:",
                            card.isSynced
                        )
                    }

                    // MARK: UUID comparison

                    let localIDs = Set(
                        localDeck.cards.map { $0.id }
                    )

                    let serverIDs = Set(
                        serverCards.map { $0.id }
                    )

                    print("")
                    print("========== UUID VERIFICATION ==========")

                    print("LOCAL IDS:", localIDs.count)
                    print("SERVER IDS:", serverIDs.count)

                    if localIDs == serverIDs {

                        print("✅ ALL CARD UUIDs MATCH")

                    } else {

                        print("❌ CARD UUID MISMATCH")

                        let missingOnServer = localIDs.subtracting(serverIDs)
                        let missingLocally = serverIDs.subtracting(localIDs)

                        print(
                            "Missing on server:",
                            missingOnServer
                        )

                        print(
                            "Missing locally:",
                            missingLocally
                        )
                    }

                    // MARK: Synced verification

                    let unsyncedCards = localDeck.cards.filter {
                        !$0.isSynced
                    }

                    print("")
                    print("========== SYNC STATE ==========")
                    print(
                        "UNSYNCED LOCAL CARDS:",
                        unsyncedCards.count
                    )

                    if localIDs == serverIDs &&
                        unsyncedCards.isEmpty {

                        print("")
                        print("🎉 CARD SYNC VERIFIED SUCCESSFULLY")

                    } else {

                        print("")
                        print("❌ CARD SYNC VERIFICATION FAILED")
                    }

                } catch {
                    print(
                        "❌ CARD VERIFICATION ERROR:",
                        error
                    )
                }
            }
        }


    }
}

#Preview {
    ContentView()
}
