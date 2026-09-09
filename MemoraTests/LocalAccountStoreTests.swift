import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct LocalAccountStoreTests {
    @Test func logoutClearsDecksCardsProfilesAndSyncState() throws {
        let fixture = try Fixture()
        defer { fixture.cleanDefaults() }
        try fixture.store.activate(userID: UUID(), modelContext: fixture.context)
        try fixture.insertAccountData()
        fixture.defaults.set(true, forKey: "hasCompletedInitialSync")
        fixture.defaults.set(123.0, forKey: "lastSuccessfulSync")
        let previousSession = try fixture.store.session()

        try fixture.store.clear(modelContext: fixture.context)

        let reloaded = ModelContext(fixture.container)
        #expect(try reloaded.fetchCount(FetchDescriptor<StudyDeck>()) == 0)
        #expect(try reloaded.fetchCount(FetchDescriptor<StudyFlashcardCard>()) == 0)
        #expect(try reloaded.fetchCount(FetchDescriptor<LocalUserProfile>()) == 0)
        #expect(fixture.store.ownerID == nil)
        #expect(!fixture.defaults.bool(forKey: "hasCompletedInitialSync"))
        #expect(fixture.defaults.double(forKey: "lastSuccessfulSync") == 0)
        #expect(throws: CancellationError.self) { try fixture.store.validate(previousSession) }
        #expect(throws: CancellationError.self) { _ = try fixture.store.session() }
    }

    @Test func switchingAccountsClearsPreviousDataAndRejectsOldSync() throws {
        let fixture = try Fixture()
        defer { fixture.cleanDefaults() }
        let firstUser = UUID()
        let secondUser = UUID()
        try fixture.store.activate(userID: firstUser, modelContext: fixture.context)
        try fixture.insertAccountData()
        let previousSession = try fixture.store.session()

        try fixture.store.activate(userID: secondUser, modelContext: fixture.context)

        #expect(fixture.store.ownerID == secondUser)
        #expect(try fixture.context.fetchCount(FetchDescriptor<StudyDeck>()) == 0)
        #expect(throws: CancellationError.self) { try fixture.store.validate(previousSession) }
        let newSession = try fixture.store.session()
        try fixture.store.validate(newSession)
    }

    @Test func restoringSameAccountPreservesUnsyncedData() throws {
        let fixture = try Fixture()
        defer { fixture.cleanDefaults() }
        let userID = UUID()
        try fixture.store.activate(userID: userID, modelContext: fixture.context)
        try fixture.insertAccountData()
        fixture.defaults.set(true, forKey: "hasCompletedInitialSync")

        fixture.store.suspend()
        try fixture.store.activate(userID: userID, modelContext: fixture.context)

        #expect(try fixture.context.fetchCount(FetchDescriptor<StudyDeck>()) == 2)
        #expect(try fixture.context.fetchCount(FetchDescriptor<StudyFlashcardCard>()) == 2)
        #expect(fixture.defaults.bool(forKey: "hasCompletedInitialSync"))
    }

    @Test func legacyUnownedCacheIsNotAssignedToNextUser() throws {
        let fixture = try Fixture()
        defer { fixture.cleanDefaults() }
        try fixture.insertAccountData()

        try fixture.store.activate(userID: UUID(), modelContext: fixture.context)

        #expect(try fixture.context.fetchCount(FetchDescriptor<StudyDeck>()) == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<LocalUserProfile>()) == 0)
    }

    @MainActor
    private struct Fixture {
        let suite = "LocalAccountStoreTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let container: ModelContainer
        let store: LocalAccountStore
        var context: ModelContext { container.mainContext }

        init() throws {
            defaults = UserDefaults(suiteName: suite)!
            store = LocalAccountStore(defaults: defaults)
            container = try ModelContainer(
                for: StudyDeck.self, StudyFlashcardCard.self, LocalUserProfile.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

        func insertAccountData() throws {
            let root = StudyDeck(title: "Private deck", subject: "Science", educationLevel: "University")
            context.insert(root)
            let child = StudyDeck(title: "Private chapter", subject: "Science", educationLevel: "University", parentDeck: root)
            context.insert(child)
            context.insert(StudyFlashcardCard(front: "Private question", back: "Private answer", deck: child))
            context.insert(StudyFlashcardCard(front: "Orphan", back: "Also private"))
            context.insert(LocalUserProfile(userId: UUID(), name: "Previous account"))
            try context.save()
        }

        func cleanDefaults() { defaults.removePersistentDomain(forName: suite) }
    }
}
