import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AppSyncManager {

    static let shared = AppSyncManager()

    private init() {}

    private var syncingSession: UUID?

    @AppStorage("hasCompletedInitialSync")
    private var hasCompletedInitialSync = false

    @AppStorage("lastSuccessfulSync")
    private var lastSuccessfulSync = 0.0

    private let automaticSyncInterval: TimeInterval = 15 * 60

    func syncIfStale(
        modelContext: ModelContext
    ) async {
        await StudyProgressSync.shared.flush(context: modelContext)
        guard shouldRunAutomaticSync else {
            print("⚠️ AUTOMATIC SYNC SKIPPED — RECENT SYNC EXISTS")
            return
        }

        await syncContent(modelContext: modelContext)
    }

    func sync(
        modelContext: ModelContext
    ) async {
        await StudyProgressSync.shared.flush(context: modelContext)
        await syncContent(modelContext: modelContext)
    }

    private func syncContent(modelContext: ModelContext) async {
        guard let session = try? LocalAccountStore.shared.session() else { return }
        guard syncingSession != session else {
            print("⚠️ APP SYNC ALREADY RUNNING")
            return
        }

        syncingSession = session

        defer {
            if syncingSession == session { syncingSession = nil }
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

                try LocalAccountStore.shared.validate(session)
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

            try LocalAccountStore.shared.validate(session)
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