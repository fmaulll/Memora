import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(
    filter: #Predicate<StudyDeck> { deck in
        !deck.needsDeletion
    },
    sort: \StudyDeck.createdAt, order: .reverse) private var decks: [StudyDeck]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var expandedDeckIDs: Set<UUID> = []

    private let accent = Color.appAccent
    private let recentLimit = 5

    private var rootDecks: [StudyDeck] {
        decks.filter { $0.parentDeck == nil }
    }

    private var favoriteDecks: [StudyDeck] {
        rootDecks.filter(\.isFavorite)
    }

    private var recentDecks: [StudyDeck] {
        Array(
            rootDecks
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(recentLimit)
        )
    }

    private func hasMatchingChild(
        _ deck: StudyDeck,
        searchText: String
    ) -> Bool {
        visibleChildDecks(for: deck).contains { child in
            child.title.localizedCaseInsensitiveContains(searchText) ||
            child.subject.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func displayedChildDecks(
        for deck: StudyDeck
    ) -> [StudyDeck] {
        let children = visibleChildDecks(for: deck)

        let trimmedSearch = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSearch.isEmpty else {
            return children
        }

        let matches = children.filter { child in
            child.title.localizedCaseInsensitiveContains(trimmedSearch) ||
            child.subject.localizedCaseInsensitiveContains(trimmedSearch)
        }

        return matches.isEmpty ? children : matches
    }

    private var filteredDecks: [StudyDeck] {
        let base: [StudyDeck]

        switch selectedFilter {
        case .all:
            base = rootDecks

        case .favorites:
            base = rootDecks.filter(\.isFavorite)

        case .recent:
            base = Array(
                rootDecks
                    .sorted { $0.createdAt > $1.createdAt }
                    .prefix(recentLimit)
            )
        }

        let trimmedSearch = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSearch.isEmpty else {
            return base
        }

        return base.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedSearch) ||
            $0.subject.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {

                VStack(spacing: 16) {
                    searchField
                    filterRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(Color.appBackground)

                Rectangle()
                    .fill(Color.appBorder)
                    .frame(height: 1)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if filteredDecks.isEmpty {
                            emptyState
                                .padding(.top, 80)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredDecks) { deck in
                                    deckSection(for: deck)
                                }
                            }
                            .padding(.top, 24)
                        }

                        Color.clear
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .background(
                    Color.appBackground
                        .ignoresSafeArea(edges: .top)
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(height: 1)
                }
        }
        .navigationBarBackButtonHidden()
        .onChange(of: searchText) { _, newValue in
            let trimmedSearch = newValue
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSearch.isEmpty else {
                return
            }

            for deck in rootDecks {
                if hasMatchingChild(
                    deck,
                    searchText: trimmedSearch
                ) {
                    expandedDeckIDs.insert(deck.id)
                }
            }
        }
    }
    
    private func visibleChildDecks(
        for deck: StudyDeck
    ) -> [StudyDeck] {
        deck.childDecks
            .filter { !$0.needsDeletion }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.appTextSecondary)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search decks or subjects...")
                    .foregroundColor(Color.appTextSecondary)
            )
                .font(.custom("PlusJakartaSans-Regular", size: 16))
                .foregroundStyle(Color.appTextPrimary)
                .tint(accent)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 10) {
            filterChip(.all, title: "All", count: rootDecks.count)
            filterChip(.favorites, title: "Favorites", count: favoriteDecks.count)
            filterChip(.recent, title: "Recent", count: recentDecks.count)
        }
    }

    private func filterChip(_ filter: LibraryFilter, title: String, count: Int) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundStyle(
                        isSelected
                            ? Color.appTextPrimary
                            : Color.appTextSecondary
                    )

                Text("\(count)")
                    .font(.custom("PlusJakartaSans-Bold", size: 12))
                    .foregroundStyle(
                        isSelected
                            ? Color.appTextPrimary
                            : Color.appTextSecondary
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        isSelected
                            ? accent.opacity(0.20)
                            : Color.appSecondarySurface,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.appSecondarySurface
                    : Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected
                            ? Color.appAccent
                            : Color.appBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func deckSection(for deck: StudyDeck) -> some View {
        let children = displayedChildDecks(for: deck)

        return VStack(spacing: 0) {
            NavigationLink {
                DeckDetailsView(deck: deck)
            } label: {
                deckCard(
                    for: deck,
                    childCount: children.count
                )
            }
            .buttonStyle(.plain)

            if expandedDeckIDs.contains(deck.id) {
                ForEach(
                    Array(children.enumerated()),
                    id: \.element.id
                ) { index, childDeck in
                    NavigationLink {
                        DeckDetailsView(deck: childDeck)
                    } label: {
                        deckCard(
                            for: childDeck,
                            isChild: true,
                            isLast: index == children.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func deckCard(
        for deck: StudyDeck,
        isChild: Bool = false,
        isLast: Bool = false,
        childCount: Int = 0
    ) -> some View {

        HStack(spacing: 14) {
            if isChild {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 6) {

                Text(deck.title)
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: isChild ? 16 : 17
                        )
                    )
                    .foregroundStyle(Color.appTextPrimary)


                HStack(spacing: 4) {
                    Button {
                        toggleFavorite(deck)
                    } label: {
                        Image(
                            systemName: deck.isFavorite
                                ? "heart.fill"
                                : "heart"
                        )
                        .foregroundStyle(
                            deck.isFavorite
                                ? Color.appError
                                : Color.appTextSecondary
                        )
                        .font(.system(size: 16))
                        .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    let childCount = visibleChildDecks(for: deck).count
                    let cardCount = deck.totalCardCount

                    Text(
                        childCount > 0
                            ? "\(cardCount) total cards"
                            : "\(cardCount) card\(cardCount == 1 ? "" : "s")"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 12
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)

                    Spacer()

                    if !isChild && childCount > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleExpanded(deck)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Text(
                                    "\(childCount) subdeck\(childCount == 1 ? "" : "s")"
                                )
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 12
                                    )
                                )
                                .foregroundStyle(Color.appTextSecondary)

                                Image(
                                    systemName:
                                        expandedDeckIDs.contains(deck.id)
                                        ? "chevron.up"
                                        : "chevron.down"
                                )
                                .font(
                                    .system(
                                        size: 13,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(
                                    expandedDeckIDs.contains(deck.id)
                                        ? Color.appAccent
                                        : Color.appTextSecondary
                                )
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(
                                Color.appSecondarySurface,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            isChild ? Color.appSecondarySurface : Color.appSurface,
            in: UnevenRoundedRectangle(
                topLeadingRadius: isChild ? 0 : 8,
                bottomLeadingRadius: isLast || expandedDeckIDs.contains(deck.id) ? 8 : !isChild && !expandedDeckIDs.contains(deck.id) ? 8 : 0,
                bottomTrailingRadius: isLast ? 8 : !isChild && !expandedDeckIDs.contains(deck.id) ? 8 : 0,
                topTrailingRadius: isChild ? 0 : 8
            )
        )
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: isChild ? 0 : 8,
                bottomLeadingRadius: isLast || expandedDeckIDs.contains(deck.id) ? 8 : !isChild && !expandedDeckIDs.contains(deck.id) ? 8 : 0,
                bottomTrailingRadius: isLast ? 8 : !isChild && !expandedDeckIDs.contains(deck.id) ? 8 : 0,
                topTrailingRadius: isChild ? 0 : 8
            )
            .stroke(Color.appBorder, lineWidth: 1)
        }
        .padding(.leading, isChild ? 24 : 0)
        .contentShape(Rectangle())
    }

    private func toggleExpanded(_ deck: StudyDeck) {
        if expandedDeckIDs.contains(deck.id) {
            expandedDeckIDs.remove(deck.id)
        } else {
            expandedDeckIDs.insert(deck.id)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(Color.appTextSecondary)

            Text("No decks found")
                .font(.custom("PlusJakartaSans-SemiBold", size: 17))
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleFavorite(_ deck: StudyDeck) {
        deck.isFavorite.toggle()
        try? modelContext.save()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Library")
                    .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                    .foregroundStyle(Color.appTextPrimary)

                Text("Your study decks")
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()
        }
    }
}

private enum LibraryFilter {
    case all
    case favorites
    case recent
}

#Preview {
    LibraryView()
}
