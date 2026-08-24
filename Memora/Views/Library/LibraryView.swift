import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \StudyDeck.createdAt, order: .reverse) private var decks: [StudyDeck]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var selectedDeck: StudyDeck?
    @State private var expandedDeckIDs: Set<UUID> = []

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let recentLimit = 5
    private let cardColors: [Color] = [.green, .blue, .orange, .purple]

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
                .foregroundStyle(.white.opacity(0.4))

            TextField("", text: $searchText, prompt: Text("Search decks or subjects...").foregroundColor(.white.opacity(0.4)))
                .font(.custom("PlusJakartaSans-Regular", size: 16))
                .foregroundStyle(.white)
                .tint(accent)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
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
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.62))

                Text("\(count)")
                    .font(.custom("PlusJakartaSans-Bold", size: 12))
                    .foregroundStyle(isSelected ? accent : .white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isSelected ? .white : .white.opacity(0.15), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? AnyShapeStyle(accent) : AnyShapeStyle(.white.opacity(0.08)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func deckSection(for deck: StudyDeck) -> some View {
        VStack(spacing: 10) {

            deckCard(for: deck)

            if expandedDeckIDs.contains(deck.id) {
                ForEach(
                    deck.childDecks.sorted {
                        $0.createdAt < $1.createdAt
                    }
                ) { childDeck in

                    deckCard(
                        for: childDeck,
                        isChild: true
                    )
                }
            }
        }
        .background(
            .white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }

    private func deckCard(
        for deck: StudyDeck,
        isChild: Bool = false
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
                    .foregroundStyle(.white)


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
                                ? .red
                                : .white.opacity(0.4)
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
                    .foregroundStyle(.white.opacity(0.5))
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
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 40, height: 40)
                    // .background(.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .background(
            .white.opacity(isChild ? 0.035 : 0.055),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    .white.opacity(isChild ? 0.08 : 0.12),
                    lineWidth: 1
                )
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
                .foregroundStyle(.white.opacity(0.2))

            Text("No decks found")
                .font(.custom("PlusJakartaSans-SemiBold", size: 17))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func color(for deck: StudyDeck) -> Color {
        guard let index = decks.firstIndex(where: { $0.id == deck.id }) else { return accent }
        return cardColors[index % cardColors.count]
    }

    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
