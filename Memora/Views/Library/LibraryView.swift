import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \StudyDeck.createdAt, order: .reverse) private var decks: [StudyDeck]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let recentLimit = 5
    private let cardColors: [Color] = [.green, .blue, .orange, .purple]

    private var favoriteDecks: [StudyDeck] {
        decks.filter(\.isFavorite)
    }

    private var recentDecks: [StudyDeck] {
        Array(decks.prefix(recentLimit))
    }

    private var filteredDecks: [StudyDeck] {
        let base: [StudyDeck]
        switch selectedFilter {
        case .all: base = decks
        case .favorites: base = favoriteDecks
        case .recent: base = recentDecks
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return base }

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
                            deckCard(for: deck, color: color(for: deck))
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

    private func deckCard(for deck: StudyDeck, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(deck.subject.uppercased())
                    .font(.custom("PlusJakartaSans-Bold", size: 12))
                    .foregroundStyle(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.18), in: Capsule())

                Spacer()

                Button {
                    toggleFavorite(deck)
                } label: {
                    Image(systemName: deck.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(deck.isFavorite ? .red : .white.opacity(0.4))
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }

            Text(deck.title)
                .font(.custom("PlusJakartaSans-Bold", size: 20))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MASTERY")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Text("0%")
                        .font(.custom("PlusJakartaSans-Bold", size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }

                ProgressView(value: 0, total: 100)
                    .tint(color)
            }

            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 12))
                Text("\(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))

                Text("·")

                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(dateLabel(for: deck.createdAt))
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
            }
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(20)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.7), lineWidth: 1.5)
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
