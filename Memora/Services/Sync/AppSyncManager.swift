import Foundation
import SwiftData

@MainActor
final class AppSyncManager {

    static let shared = AppSyncManager()

    private init() {}

    private var isSyncing = false

    func sync(
        modelContext: ModelContext
    ) async {

        // Prevent two syncs from running simultaneously
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }

        isSyncing = true

        defer {
            isSyncing = false
        }

        do {
            try await SyncManager.shared.downloadAll(
                modelContext: modelContext
            )

            print("APP SYNC SUCCESS")

        } catch {
            print("APP SYNC FAILED:", error)
        }
    }
}