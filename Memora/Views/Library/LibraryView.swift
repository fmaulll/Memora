import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(filter: #Predicate<StudyDeck> { !$0.needsDeletion }, sort: \StudyDeck.createdAt, order: .reverse)
    private var decks: [StudyDeck]
    @Environment(\.modelContext) private var modelContext
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var selectedSort: LibrarySort = .recentlyStudied
    @State private var selectedDeck: StudyDeck?
    @State private var expandedDeckIDs = Set<UUID>()
    @State private var isShowingCreateDeck = false
    @State private var errorMessage: String?

    private var isBrowsing: Bool {
        selectedFilter == .all && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let catalog = LibraryCatalog(decks: decks, isSubscribed: subscriptionManager.isSubscribed, now: timeline.date)
            let rows = catalog.rows(filter: selectedFilter, search: searchText, sort: selectedSort, expanded: expandedDeckIDs)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    searchField
                    filterRow(catalog)
                    sortRow
                    if rows.isEmpty {
                        emptyState(isLibraryEmpty: catalog.entries.isEmpty)
                            .padding(.top, 32)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(rows) { row in
                                deckCard(row, childCount: catalog.children(of: row.entry).count)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(item: $selectedDeck) { deck in
            DeckDetailsView(deck: deck)
        }
        .navigationDestination(isPresented: $isShowingCreateDeck) {
            NewStudyDeckView(onFinish: { deck in
                isShowingCreateDeck = false
                selectedDeck = deck
            })
        }
        .alert("Couldn't save favorite", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Please try again.") }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.appTextSecondary)
            TextField("Search decks, subdecks, or subjects", text: $searchText)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(Color.appTextPrimary)
                .tint(Color.appAccent)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 32, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .libraryPanel()
    }

    private func filterRow(_ catalog: LibraryCatalog) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    let count = catalog.results(filter: filter, search: searchText, sort: selectedSort).count
                    Button {
                        selectedFilter = filter
                        if filter == .recent { selectedSort = .recentlyStudied }
                    } label: {
                        HStack(spacing: 8) {
                            Text(filter.rawValue)
                            Text("\(count)")
                        }
                        .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                        .foregroundStyle(selectedFilter == filter ? Color.appBackground : Color.appTextSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(selectedFilter == filter ? Color.appAccent : Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(selectedFilter == filter ? Color.appAccent : Color.appBorder, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                }
            }
        }
    }

    private var sortRow: some View {
        HStack(alignment: .center) {
            Text(selectedFilter == .recent ? "5 most recently studied decks" : selectedFilter == .favorites ? "Your saved decks and subdecks" : "Your collection")
                .font(.custom("PlusJakartaSans-Regular", size: 12))
                .foregroundStyle(Color.appTextSecondary)
            Spacer(minLength: 8)
            Menu {
                Picker("Sort library", selection: $selectedSort) {
                    ForEach(LibrarySort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
            } label: {
                Label(selectedSort.rawValue, systemImage: "arrow.up.arrow.down")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundStyle(Color.appAccent)
                    .padding(.vertical, 8)
            }
            .accessibilityLabel("Sort by \(selectedSort.rawValue)")
        }
    }

    private func deckCard(_ row: LibraryRow, childCount: Int) -> some View {
        let entry = row.entry
        let deck = entry.deck
        let progress = entry.progress
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Button { selectedDeck = deck } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if !entry.breadcrumb.isEmpty && (!isBrowsing || row.depth > 2) {
                            Text(entry.breadcrumb)
                                .font(.custom("PlusJakartaSans-Regular", size: 11))
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(2)
                        }
                        Text(deck.title)
                            .font(.custom("PlusJakartaSans-Bold", size: 17))
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.leading)
                        Text("\(progress.totalCount) card\(progress.totalCount == 1 ? "" : "s")" + (progress.dueCount > 0 ? " · \(progress.dueCount) due" : ""))
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundStyle(Color.appTextSecondary)
                        statusLabel(progress)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open deck details")

                Button { toggleFavorite(deck) } label: {
                    Image(systemName: deck.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundStyle(deck.isFavorite ? Color.appError : Color.appTextSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(deck.isFavorite ? "Remove \(deck.title) from favorites" : "Favorite \(deck.title)")
            }
            if childCount > 0 {
                // Search and Favorites remain flat so their counts match results.
                // Their subdeck link opens the parent; All supports inline browsing.
                Button {
                    if isBrowsing {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if !expandedDeckIDs.insert(deck.id).inserted { expandedDeckIDs.remove(deck.id) }
                        }
                    } else {
                        selectedDeck = deck
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(childCount) subdeck\(childCount == 1 ? "" : "s")")
                        Image(systemName: isBrowsing ? (expandedDeckIDs.contains(deck.id) ? "chevron.up" : "chevron.down") : "chevron.right")
                    }
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundStyle(Color.appAccent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isBrowsing ? "\(expandedDeckIDs.contains(deck.id) ? "Collapse" : "Expand") \(childCount) subdecks in \(deck.title)" : "Open \(childCount) subdecks in \(deck.title)")
            }
        }
        .padding(16)
        .libraryPanel(isChild: row.depth > 0)
        .padding(.leading, CGFloat(min(row.depth, 3)) * 16)
    }

    @ViewBuilder
    private func statusLabel(_ progress: DeckProgressSummary) -> some View {
        if progress.isLocked {
            status("Locked", icon: "lock.fill", color: .appWarning)
        } else if progress.hasGenerationFailure {
            status("Generation needs attention", icon: "exclamationmark.circle", color: .appError)
        } else if progress.isGenerating {
            status("Generating cards…", icon: "sparkles", color: .appAccent)
        } else if progress.hasActiveSession {
            status("Session in progress · \(progress.sessionRemaining) left", icon: "play.circle", color: .appInfo)
        }
    }

    private func status(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.custom("PlusJakartaSans-Regular", size: 12))
            .foregroundStyle(color)
    }

    private func emptyState(isLibraryEmpty: Bool) -> some View {
        let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let title = isLibraryEmpty ? "Your library starts here" : isSearching ? "No matching decks" : selectedFilter == .favorites ? "No favorites yet" : "No study activity yet"
        let detail = isLibraryEmpty ? "Create your first deck and give Mr. Ed something to work with."
            : isSearching ? "Try another deck title, subdeck, or subject."
            : selectedFilter == .favorites ? "Tap a heart to keep a deck or subdeck here."
            : "Study a deck and it will appear here. New decks are waiting in All."
        return VStack(spacing: 16) {
            Image(systemName: isSearching ? "magnifyingglass" : "books.vertical")
                .font(.system(size: 40)).foregroundStyle(Color.appTextSecondary)
            Text(title).font(.custom("PlusJakartaSans-Bold", size: 22)).foregroundStyle(Color.appTextPrimary)
            Text(detail).font(.custom("PlusJakartaSans-Regular", size: 14)).foregroundStyle(Color.appTextSecondary)
            AppButton(title: isLibraryEmpty ? "Create a deck" : isSearching ? "Clear search" : "Browse all decks", foreground: Color.appBackground, background: Color.appAccent) {
                if isLibraryEmpty { isShowingCreateDeck = true }
                else if isSearching { searchText = "" }
                else { selectedFilter = .all }
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func toggleFavorite(_ deck: StudyDeck) {
        let previousFavorite = deck.isFavorite
        let previousSync = deck.isSynced
        deck.isFavorite.toggle()
        deck.isSynced = false
        do { try modelContext.save() }
        catch {
            deck.isFavorite = previousFavorite
            deck.isSynced = previousSync
            errorMessage = "Your change wasn't saved. Please try again."
        }
    }
}

private extension View {
    func libraryPanel(isChild: Bool = false) -> some View {
        background(isChild ? Color.appSecondarySurface : Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }
}

#Preview {
    NavigationStack { LibraryView() }
}
