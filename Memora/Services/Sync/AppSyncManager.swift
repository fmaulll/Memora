import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AppSyncManager {

    static let shared = AppSyncManager()

    private init() {}

    private var isSyncing = false

    @AppStorage("hasCompletedInitialSync")
    private var hasCompletedInitialSync = false

    func sync(
        modelContext: ModelContext
    ) async {

        guard !isSyncing else {
            print("⚠️ APP SYNC ALREADY RUNNING")
            return
        }

        isSyncing = true

        defer {
            isSyncing = false
        }

        do {

            // -------------------------------------------------
            // FIRST INSTALL
            // -------------------------------------------------

            if !hasCompletedInitialSync {

                print("")
                print("========== INITIAL SYNC ==========")
                print("LOCAL DATABASE HAS NOT BEEN INITIALIZED")

                try await SyncManager.shared.downloadAll(
                    modelContext: modelContext
                )

                hasCompletedInitialSync = true

                print("✅ INITIAL DOWNLOAD COMPLETE")
                print("LOCAL DATABASE INITIALIZED")

                return
            }

            // -------------------------------------------------
            // NORMAL SYNC
            // -------------------------------------------------

            print("")
            print("========== NORMAL APP SYNC ==========")

            try await SyncManager.shared.sync(
                modelContext: modelContext
            )

            print("✅ APP SYNC SUCCESS")

        } catch {

            print("❌ APP SYNC FAILED:", error)

        }
    }
}