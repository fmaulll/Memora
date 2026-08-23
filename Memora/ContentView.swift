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


        // Button("Logout / Clear Token") {
        //     KeychainService.shared.deleteAccessToken()
        // }

        // Button("Test State — Created") {
        //     do {
        //         let descriptor = FetchDescriptor<StudyFlashcardCard>(
        //             predicate: #Predicate<StudyFlashcardCard> { card in
        //                 card.syncState == 1
        //             }
        //         )

        //         let cards = try modelContext.fetch(descriptor)

        //         print("")
        //         print("========== CREATED STATE ==========")
        //         print("COUNT:", cards.count)

        //         for card in cards {
        //             print("ID:", card.id)
        //             print("FRONT:", card.front)
        //             print("SYNC STATE:", card.syncState)
        //             print("SYNCED:", card.isSynced)
        //         }

        //     } catch {
        //         print("STATE TEST ERROR:", error)
        //     }
        // }

        // Button("Test State — Updated") {
        //     do {
        //         let descriptor = FetchDescriptor<StudyFlashcardCard>(
        //             predicate: #Predicate<StudyFlashcardCard> { card in
        //                 card.syncState == 2
        //             }
        //         )

        //         let cards = try modelContext.fetch(descriptor)

        //         print("")
        //         print("========== UPDATED STATE ==========")
        //         print("COUNT:", cards.count)

        //         for card in cards {
        //             print("ID:", card.id)
        //             print("FRONT:", card.front)
        //             print("SYNC STATE:", card.syncState)
        //             print("SYNCED:", card.isSynced)
        //         }

        //     } catch {
        //         print("STATE TEST ERROR:", error)
        //     }
        // }

        // Button("Test State — Deleted") {
        //     do {
        //         let descriptor = FetchDescriptor<StudyFlashcardCard>(
        //             predicate: #Predicate<StudyFlashcardCard> { card in
        //                 card.syncState == 3
        //             }
        //         )

        //         let cards = try modelContext.fetch(descriptor)

        //         print("")
        //         print("========== DELETED STATE ==========")
        //         print("COUNT:", cards.count)

        //         for card in cards {
        //             print("ID:", card.id)
        //             print("FRONT:", card.front)
        //             print("SYNC STATE:", card.syncState)
        //             print("SYNCED:", card.isSynced)
        //             print("NEEDS DELETION:", card.needsDeletion)
        //         }

        //     } catch {
        //         print("STATE TEST ERROR:", error)
        //     }
        // }

        // Button("Test Unified Sync") {
        //     Task {
        //         do {

        //             try await SyncManager.shared.sync(
        //                 modelContext: modelContext
        //             )

        //             print("")
        //             print("🎉 UNIFIED SYNC SUCCESS")

        //         } catch {
        //             print("")
        //             print("❌ UNIFIED SYNC FAILED:", error)
        //         }
        //     }
        // }

        // Button("Test Orphan Cards") {
        //     do {
        //         let descriptor = FetchDescriptor<StudyFlashcardCard>()

        //         let cards = try modelContext.fetch(descriptor)

        //         print("")
        //         print("========== ORPHAN CARDS ==========")

        //         var count = 0

        //         for card in cards {

        //             if card.deck == nil {

        //                 count += 1

        //                 print("")
        //                 print("ID:", card.id)
        //                 print("FRONT:", card.front)
        //                 print("SYNC STATE:", card.syncState)
        //                 print("SYNCED:", card.isSynced)
        //                 print("NEEDS DELETION:", card.needsDeletion)
        //             }
        //         }

        //         print("")
        //         print("ORPHAN COUNT:", count)

        //     } catch {
        //         print("ORPHAN TEST ERROR:", error)
        //     }
        // }

        // Button("Clean Orphan Test Cards") {
        //     do {
        //         let descriptor = FetchDescriptor<StudyFlashcardCard>()

        //         let cards = try modelContext.fetch(descriptor)

        //         var deletedCount = 0

        //         for card in cards {
        //             if card.deck == nil {
        //                 print("Deleting orphan:", card.id, card.front)

        //                 modelContext.delete(card)
        //                 deletedCount += 1
        //             }
        //         }

        //         try modelContext.save()

        //         print("")
        //         print("========== ORPHAN CLEANUP ==========")
        //         print("DELETED:", deletedCount)

        //     } catch {
        //         print("ORPHAN CLEANUP ERROR:", error)
        //     }
        // }

    }
}

#Preview {
    ContentView()
}
