import Foundation
import SwiftData

/// The shared SwiftData cache belongs to exactly one backend account at a time.
@MainActor
final class LocalAccountStore {
    static let shared = LocalAccountStore()

    private let defaults: UserDefaults
    private(set) var revision = UUID()
    private var isActive = false

    var ownerID: UUID? {
        defaults.string(forKey: "localCacheOwnerID").flatMap(UUID.init(uuidString:))
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func suspend() {
        revision = UUID()
        isActive = false
    }

    func session() throws -> UUID {
        guard isActive else { throw CancellationError() }
        return revision
    }

    func validate(_ session: UUID) throws {
        guard isActive, session == revision else { throw CancellationError() }
    }

    func validateRevision(_ revision: UUID) throws {
        guard revision == self.revision else { throw CancellationError() }
    }

    func activate(userID: UUID, modelContext: ModelContext) throws {
        if ownerID != userID {
            try clear(modelContext: modelContext)
            defaults.set(userID.uuidString, forKey: "localCacheOwnerID")
        }
        isActive = true
    }

    func clear(modelContext: ModelContext) throws {
        suspend()
        // Delete local objects directly; do not mark them for server deletion.
        // Explicitly include orphan cards and every chapter, not just root decks.
        do {
            let cards = try modelContext.fetch(FetchDescriptor<StudyFlashcardCard>())
            let decks = try modelContext.fetch(FetchDescriptor<StudyDeck>())
            let profiles = try modelContext.fetch(FetchDescriptor<LocalUserProfile>())
            for deck in decks { deck.parentDeck = nil }
            for card in cards { modelContext.delete(card) }
            for deck in decks { modelContext.delete(deck) }
            for profile in profiles { modelContext.delete(profile) }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        defaults.removeObject(forKey: "localCacheOwnerID")
        defaults.removeObject(forKey: "hasCompletedInitialSync")
        defaults.removeObject(forKey: "lastSuccessfulSync")
    }
}
