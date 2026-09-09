import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct LibraryCatalogTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func allCountsRootsAndExpansionSupportsNestedSubdecks() throws {
        let container = try makeContainer()
        let root = deck("Biology", in: container)
        let child = deck("Cells", in: container, parent: root)
        let nested = deck("Mitosis", in: container, parent: child)
        let catalog = LibraryCatalog(decks: [root, child, nested], isSubscribed: true, now: now)
        #expect(catalog.results(filter: .all, search: "", sort: .newest).count == 1)
        let closed = catalog.rows(filter: .all, search: "", sort: .newest, expanded: [])
        #expect(closed.map(\.id) == [root.id])
        let open = catalog.rows(filter: .all, search: "", sort: .newest, expanded: [root.id, child.id])
        #expect(open.map(\.id) == [root.id, child.id, nested.id])
        #expect(open.map(\.depth) == [0, 1, 2])
    }

    @Test func searchFindsNestedSubdeckAndIncludesItsPath() throws {
        let container = try makeContainer()
        let root = deck("Biology", in: container)
        let child = deck("Cells", in: container, parent: root)
        let nested = deck("Mitosis", in: container, parent: child)
        let catalog = LibraryCatalog(decks: [root, child, nested], isSubscribed: true, now: now)
        let results = catalog.results(filter: .all, search: "  MITOSIS  ", sort: .alphabetical)
        #expect(results.map(\.id) == [nested.id])
        #expect(results.first?.breadcrumb == "Biology / Cells")
        let rows = catalog.rows(filter: .all, search: "mitosis", sort: .alphabetical, expanded: [root.id])
        #expect(rows.count == results.count)
        #expect(rows.first?.depth == 0)
    }

    @Test func favoritesIncludeSubdecksAndCountsMatchFlatResults() throws {
        let container = try makeContainer()
        let root = deck("Root", in: container)
        let child = deck("Favorite chapter", in: container, parent: root)
        child.isFavorite = true
        let catalog = LibraryCatalog(decks: [root, child], isSubscribed: true, now: now)
        let favorites = catalog.results(filter: .favorites, search: "", sort: .newest)
        let rows = catalog.rows(filter: .favorites, search: "", sort: .newest, expanded: [root.id, child.id])
        #expect(favorites.map(\.id) == [child.id])
        #expect(rows.count == favorites.count)
        #expect(catalog.results(filter: .favorites, search: "no match", sort: .newest).isEmpty)
    }

    @Test func deletedSubtreesDoNotAppearOrCreateAnExpansionControl() throws {
        let container = try makeContainer()
        let root = deck("Root", in: container)
        let deleted = deck("Deleted", in: container, parent: root)
        deleted.needsDeletion = true
        let nested = deck("Hidden favorite", in: container, parent: deleted)
        nested.isFavorite = true
        let catalog = LibraryCatalog(decks: [root, nested], isSubscribed: true, now: now)
        let entry = try #require(catalog.entries.first)
        #expect(catalog.entries.count == 1)
        #expect(catalog.children(of: entry).isEmpty)
        #expect(catalog.results(filter: .favorites, search: "", sort: .newest).isEmpty)
    }

    @Test func recentUsesActualStudyDatesRatherThanCreationAndLimitsToFive() throws {
        let container = try makeContainer()
        var studied: [StudyDeck] = []
        for index in 0..<7 {
            let item = deck("Deck \(index)", in: container)
            let card = StudyFlashcardCard(front: "Q", back: "A")
            card.lastReviewedAt = now.addingTimeInterval(-Double(index * 60))
            item.cards.append(card)
            studied.append(item)
        }
        let newest = deck("Never studied", in: container)
        let catalog = LibraryCatalog(decks: studied + [newest], isSubscribed: true, now: now)
        let recent = catalog.results(filter: .recent, search: "", sort: .recentlyStudied)
        #expect(recent.map(\.id) == Array(studied.prefix(5)).map(\.id))
        #expect(!recent.contains { $0.id == newest.id })
    }

    @Test func sortingUsesDescendantActivityAndSupportsAlphabeticalAndNewest() throws {
        let container = try makeContainer()
        let older = deck("Alpha", in: container)
        older.createdAt = now.addingTimeInterval(-100)
        let newer = deck("Zebra", in: container)
        newer.createdAt = now
        let child = deck("Chapter", in: container, parent: older)
        let card = StudyFlashcardCard(front: "Q", back: "A")
        card.lastReviewedAt = now
        child.cards.append(card)
        let catalog = LibraryCatalog(decks: [older, newer, child], isSubscribed: true, now: now)
        #expect(catalog.results(filter: .all, search: "", sort: .recentlyStudied).map(\.id) == [older.id, newer.id])
        #expect(catalog.results(filter: .all, search: "", sort: .alphabetical).map(\.id) == [older.id, newer.id])
        #expect(catalog.results(filter: .all, search: "", sort: .newest).map(\.id) == [newer.id, older.id])
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: StudyDeck.self, StudyFlashcardCard.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func deck(_ title: String, in container: ModelContainer, parent: StudyDeck? = nil) -> StudyDeck {
        let deck = StudyDeck(title: title, subject: "Science", educationLevel: "University", parentDeck: parent)
        container.mainContext.insert(deck)
        return deck
    }
}
