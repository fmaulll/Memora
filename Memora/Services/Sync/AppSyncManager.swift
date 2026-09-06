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

    @AppStorage("lastSuccessfulSync")
    private var lastSuccessfulSync = 0.0

    private let automaticSyncInterval: TimeInterval = 15 * 60

    func syncIfStale(
        modelContext: ModelContext
    ) async {
        guard shouldRunAutomaticSync else {
            print("⚠️ AUTOMATIC SYNC SKIPPED — RECENT SYNC EXISTS")
            return
        }

        await sync(modelContext: modelContext)
    }

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
                lastSuccessfulSync = Date().timeIntervalSince1970

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

            lastSuccessfulSync = Date().timeIntervalSince1970
            print("✅ APP SYNC SUCCESS")

        } catch {

            print("❌ APP SYNC FAILED:", error)

        }
    }

    private var shouldRunAutomaticSync: Bool {
        guard hasCompletedInitialSync else {
            return true
        }

        let secondsSinceLastSync =
            Date().timeIntervalSince1970 - lastSuccessfulSync

        return secondsSinceLastSync >= automaticSyncInterval
    }
}