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
    @State private var selectedDeck: StudyDeck?
    @State private var expandedDeckIDs: Set<UUID> = []

    private let accent = Color.appAccent
    private let recentLimit = 5

    private var rootDecks: [StudyDeck] {
        decks.filter { $0.parentDeck == nil }
    }

    private var favoriteDecks: [StudyDeck] {
        decks.filter(\.isFavorite)
    }

    private var recentDecks: [StudyDeck] {
        Array(decks.prefix(recentLimit))
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                searchField
                    .padding(.top, 20)

                filterRow
                    .padding(.top, 20)

                if filteredDecks.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    VStack(spacing: 16) {
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
        .navigationBarBackButtonHidden()
        .navigationDestination(item: $selectedDeck) { deck in
            DeckDetailsView(deck: deck)
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
            filterChip(.all, title: "All", count: decks.count)
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
                            ? accent.opacity(0.35)
                            : Color.appSecondarySurface,
                        in: Capsule()
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color.appSecondarySurface
                    : Color.appSurface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(
                        isSelected ? accent : Color.appBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func deckSection(for deck: StudyDeck) -> some View {
        
        VStack(spacing: 0) {
            let sortedChildren = deck.childDecks
                .filter { !$0.needsDeletion }
                .sorted {
                    $0.createdAt < $1.createdAt
                }

            deckCard(for: deck)

            if expandedDeckIDs.contains(deck.id) {
                ForEach(Array(sortedChildren.enumerated()), id: \.element.id) { index, childDeck in
                    deckCard(
                        for: childDeck,
                        isChild: true,
                        isLast: index == sortedChildren.count - 1
                    )
                }
            }
        }
    }

    private func deckCard(
        for deck: StudyDeck,
        isChild: Bool = false,
        isLast: Bool = false
    ) -> some View {

        HStack(spacing: 14) {


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

                    Text(
                        "\(deck.totalCardCount) card\(deck.totalCardCount == 1 ? "" : "s")"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 13
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            if !deck.childDecks.isEmpty {
                Button {
                    toggleExpanded(deck)
                } label: {
                    Image(
                        systemName:
                            expandedDeckIDs.contains(deck.id)
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 40, height: 40)
                    // .background(.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
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
        .onTapGesture {
            selectedDeck = deck
        }
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
}

private enum LibraryFilter {
    case all
    case favorites
    case recent
}

#Preview {
    NavigationStack {
        LibraryView()
    }
}
