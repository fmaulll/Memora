import Foundation

enum LibraryFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case recent = "Recent"
}

enum LibrarySort: String, CaseIterable {
    case recentlyStudied = "Recently studied"
    case newest = "Newest"
    case alphabetical = "A–Z"
}

@MainActor
struct LibraryEntry: Identifiable {
    nonisolated let id: UUID
    let deck: StudyDeck
    let breadcrumb: String
    let progress: DeckProgressSummary
    let directlyStudiedAt: Date?
}

@MainActor
struct LibraryRow: Identifiable {
    nonisolated let id: UUID
    let entry: LibraryEntry
    let depth: Int
}

/// Uses the same candidates for filter counts and results. Search and Favorites
/// expose subdecks directly, while All keeps the browsable hierarchy.
@MainActor
struct LibraryCatalog {
    let entries: [LibraryEntry]
    static let recentLimit = 5

    init(decks: [StudyDeck], isSubscribed: Bool, now: Date) {
        var entries: [LibraryEntry] = []
        var seen = Set<UUID>()
        func visit(_ deck: StudyDeck, ancestors: [String]) {
            guard !deck.needsDeletion, seen.insert(deck.id).inserted else { return }
            entries.append(LibraryEntry(
                id: deck.id,
                deck: deck,
                breadcrumb: ancestors.joined(separator: " / "),
                progress: DeckProgressSummary(deck: deck, isSubscribed: isSubscribed, now: now),
                directlyStudiedAt: deck.cards.filter { !$0.needsDeletion }
                    .compactMap(\.lastReviewedAt).filter { $0 <= now }.max()
            ))
            for child in deck.childDecks { visit(child, ancestors: ancestors + [deck.title]) }
        }
        for root in decks where root.parentDeck == nil { visit(root, ancestors: []) }
        self.entries = entries
    }

    func children(of entry: LibraryEntry) -> [LibraryEntry] {
        entries.filter { $0.deck.parentDeck?.id == entry.id }.sorted {
            if $0.deck.createdAt != $1.deck.createdAt { return $0.deck.createdAt < $1.deck.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func results(filter: LibraryFilter, search: String, sort: LibrarySort) -> [LibraryEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates: [LibraryEntry]
        switch filter {
        case .all:
            candidates = query.isEmpty ? entries.filter { $0.deck.parentDeck == nil } : entries
        case .favorites:
            candidates = entries.filter { $0.deck.isFavorite }
        case .recent:
            candidates = Array(entries.filter { $0.directlyStudiedAt != nil }.sorted {
                if $0.directlyStudiedAt != $1.directlyStudiedAt {
                    return ($0.directlyStudiedAt ?? .distantPast) > ($1.directlyStudiedAt ?? .distantPast)
                }
                return $0.id.uuidString < $1.id.uuidString
            }.prefix(Self.recentLimit))
        }
        return candidates.filter {
            query.isEmpty || $0.deck.title.localizedCaseInsensitiveContains(query)
                || $0.deck.subject.localizedCaseInsensitiveContains(query)
        }.sorted { lhs, rhs in
            switch sort {
            case .recentlyStudied:
                let left = filter == .recent ? lhs.directlyStudiedAt : lhs.progress.lastStudiedAt
                let right = filter == .recent ? rhs.directlyStudiedAt : rhs.progress.lastStudiedAt
                if left != right { return (left ?? .distantPast) > (right ?? .distantPast) }
            case .newest:
                if lhs.deck.createdAt != rhs.deck.createdAt { return lhs.deck.createdAt > rhs.deck.createdAt }
            case .alphabetical:
                let comparison = lhs.deck.title.localizedStandardCompare(rhs.deck.title)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            }
            if lhs.deck.createdAt != rhs.deck.createdAt { return lhs.deck.createdAt > rhs.deck.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func rows(filter: LibraryFilter, search: String, sort: LibrarySort, expanded: Set<UUID>) -> [LibraryRow] {
        let results = results(filter: filter, search: search, sort: sort)
        let isBrowsing = filter == .all && search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        var rows: [LibraryRow] = []
        func append(_ entry: LibraryEntry, depth: Int) {
            rows.append(LibraryRow(id: entry.id, entry: entry, depth: depth))
            if isBrowsing && expanded.contains(entry.id) {
                for child in children(of: entry) { append(child, depth: depth + 1) }
            }
        }
        for entry in results { append(entry, depth: 0) }
        return rows
    }
}
