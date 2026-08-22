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
                    title: "Offline Test",
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

        Button("Verify Uploaded Deck") {
            Task {
                let deckID = UUID(
                    uuidString: "E6F1F6FE-D07D-4FFA-AE79-1FE39051D719"
                )!

                do {
                    // MARK: Server verification

                    let serverDeck = try await DeckAPI.shared.get(
                        id: deckID
                    )

                    print("========== SERVER VERIFICATION ==========")
                    print("SERVER DECK FOUND")
                    print("ID:", serverDeck.id)
                    print("TITLE:", serverDeck.title)
                    print("SUBJECT:", serverDeck.subject)
                    print("FAVORITE:", serverDeck.isFavorite)

                    // MARK: Local verification

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
                    print("========== LOCAL VERIFICATION ==========")
                    print("LOCAL DECK FOUND")
                    print("ID:", localDeck.id)
                    print("TITLE:", localDeck.title)
                    print("SUBJECT:", localDeck.subject)
                    print("SYNCED:", localDeck.isSynced)

                    // MARK: UUID verification

                    print("")
                    print("========== UUID VERIFICATION ==========")

                    print("LOCAL :", localDeck.id)
                    print("SERVER:", serverDeck.id)

                    if localDeck.id == serverDeck.id {
                        print("✅ UUID MATCH")
                    } else {
                        print("❌ UUID MISMATCH")
                    }

                    // MARK: Final result

                    print("")
                    print("========== FINAL RESULT ==========")

                    if localDeck.id == serverDeck.id &&
                        localDeck.isSynced {

                        print("🎉 DECK SYNC VERIFIED SUCCESSFULLY")

                    } else {

                        print("❌ DECK SYNC VERIFICATION FAILED")
                    }

                } catch {
                    print("❌ VERIFICATION ERROR:", error)
                }
            }
        }


    }
}

#Preview {
    ContentView()
}
