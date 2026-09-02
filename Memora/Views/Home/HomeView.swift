import SwiftUI
import SwiftData

struct HomeView: View {

    @Query(sort: \StudyDeck.createdAt, order: .reverse) private var decks: [StudyDeck]
    @State private var selectedTab: BottomBar.Tab = .home
    @State private var isShowingNewStudyDeck = false
    @State private var selectedDeck: StudyDeck?
    @State private var authManager = AuthManager.shared

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    private let accent = Color.appAccent

    init(initialDeck: StudyDeck? = nil) {
        _selectedTab = State(
            initialValue: initialDeck == nil ? .home : .library
        )
        _selectedDeck = State(initialValue: initialDeck)
    }

    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }

    private var rootDecks: [StudyDeck] {
        decks.filter { $0.parentDeck == nil && !$0.needsDeletion }
    }

    private func cards(in deck: StudyDeck) -> [StudyFlashcardCard] {
        deck.cards + deck.childDecks.flatMap(\.cards)
    }

    private func dueCardCount(in deck: StudyDeck) -> Int {
        cards(in: deck).filter {
            guard let nextReviewAt = $0.nextReviewAt else {
                return false
            }

            return nextReviewAt <= .now
        }.count
    }

    private func newCardCount(in deck: StudyDeck) -> Int {
        cards(in: deck).filter { $0.reviewCount == 0 }.count
    }

    private var recommendedDeck: StudyDeck? {
        if let activeDeck = rootDecks.first(
            where: { $0.isStudySessionActive || $0.isStudyAllSessionActive }
        ) {
            return activeDeck
        }

        if let dueDeck = rootDecks.max(by: {
            dueCardCount(in: $0) < dueCardCount(in: $1)
        }), dueCardCount(in: dueDeck) > 0 {
            return dueDeck
        }

        if let newDeck = rootDecks.first(where: { newCardCount(in: $0) > 0 }) {
            return newDeck
        }

        return rootDecks.first
    }

    private var readyCardCount: Int {
        rootDecks.reduce(0) { $0 + dueCardCount(in: $1) }
    }

    var body: some View {
        ZStack {
            AppBackground {
                Group {
                    if selectedTab == .home {
                        homeContent
                    } else {
                        LibraryView()
                    }
                }
            }

            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.appBackground.ignoresSafeArea(edges: .top)
                    )
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.appBorder)
                            .frame(height: 1)
                    }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(selectedTab: $selectedTab) {
                isShowingNewStudyDeck = true
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $isShowingNewStudyDeck) {
            NewStudyDeckView(
                onFinish: { deck in
                    isShowingNewStudyDeck = false
                    selectedTab = .library
                    selectedDeck = deck
                }
            )
        }
        .navigationDestination(item: $selectedDeck) { deck in
            DeckDetailsView(deck: deck)
        }
    }

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                if let recommendedDeck {
                    recommendationCard(for: recommendedDeck)
                } else {
                    emptyState
                }

                if !rootDecks.isEmpty {
                    readySection
                    recentDecksSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
    }

    private var header: some View {
        HStack {
            if selectedTab == .home {
                VStack(alignment: .leading, spacing: 6) {
                    Text(authManager.currentUser?.name ?? "User")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                developerMenu
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("\(decks.count) deck\(decks.count == 1 ? "" : "s") · \(totalCardCount) cards")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Button {
                    isShowingNewStudyDeck = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.appBackground)
                        .frame(width: 52, height: 52)
                        .background(accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Create a new study deck")
            }
        }
    }

    private var developerMenu: some View {
        Menu {
            Button("Logout / Clear Token") {
                KeychainService.shared.deleteAccessToken()
            }

            Button("Reset Onboarding", role: .destructive) {
                hasCompletedOnboarding = false
            }

            Button("Fake Subscribe") {
                SubscriptionManager.shared.isSubscribed = true
            }

            Button("Fake Unsubscribe") {
                SubscriptionManager.shared.isSubscribed = false
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 44, height: 44)
                .background(Color.appSurface, in: Circle())
                .overlay {
                    Circle().stroke(Color.appBorder, lineWidth: 1)
                }
        }
        .accessibilityLabel("Home options")
    }

    private func recommendationCard(for deck: StudyDeck) -> some View {
        let dueCards = dueCardCount(in: deck)
        let newCards = newCardCount(in: deck)
        let isResuming = deck.isStudySessionActive || deck.isStudyAllSessionActive

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MR. ED'S VERDICT")
                        .font(.custom("PlusJakartaSans-Bold", size: 11))
                        .foregroundStyle(accent)

                    Text(recommendationMessage(
                        isResuming: isResuming,
                        dueCards: dueCards,
                        newCards: newCards
                    ))
                    .font(.custom("PlusJakartaSans-ExtraBold", size: 26))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineSpacing(-2)
                }

                Spacer(minLength: 12)

                Image("MrEdJudging")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 88)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(deck.title)
                    .font(.custom("PlusJakartaSans-Bold", size: 18))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                Text(recommendationDetail(
                    dueCards: dueCards,
                    newCards: newCards,
                    totalCards: deck.totalCardCount
                ))
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)
            }

            Button {
                selectedDeck = deck
            } label: {
                Label("Open deck", systemImage: "arrow.right")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var readySection: some View {
        VStack(alignment: .leading, spacing: readyCardCount == 0 ? 0 :10) {
            Text("READY NOW")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(Color.appTextSecondary)

            Text(
                readyCardCount == 0
                    ? "Nothing is due right now. A suspiciously rare moment of peace."
                    : "\(readyCardCount) card\(readyCardCount == 1 ? "" : "s") waiting for you."
            )
            .font(.custom("PlusJakartaSans-Regular", size: 14))
            .foregroundStyle(Color.appTextSecondary)
        }
        .padding(16)
        .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var recentDecksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR DECKS")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(Color.appTextSecondary)

            ForEach(rootDecks.prefix(3)) { deck in
                Button {
                    selectedDeck = deck
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: deck.isFavorite ? "star.fill" : "book.closed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(deck.isFavorite ? Color.appWarning : Color.appInfo)
                            .frame(width: 34, height: 34)
                            .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(deck.title)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundStyle(Color.appTextPrimary)
                                .lineLimit(1)

                            Text("\(dueCardCount(in: deck)) due · \(deck.totalCardCount) cards")
                                .font(.custom("PlusJakartaSans-Regular", size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 62)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("MR. ED'S VERDICT")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(accent)

            Text("No deck. No progress.\nA clean slate, then.")
                .font(.custom("PlusJakartaSans-ExtraBold", size: 26))
                .foregroundStyle(Color.appTextPrimary)
                .lineSpacing(-2)

            Text("Give Mr. Ed something to work with.")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(Color.appTextSecondary)

            Button {
                isShowingNewStudyDeck = true
            } label: {
                Label("Create a deck", systemImage: "plus")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private func recommendationMessage(
        isResuming: Bool,
        dueCards: Int,
        newCards: Int
    ) -> String {
        if isResuming {
            return "You started this.\nFinish it."
        }

        if dueCards > 0 {
            return "These cards have been\nwaiting long enough."
        }

        if newCards > 0 {
            return "A new deck.\nTry not to waste it."
        }

        return "You have a deck.\nUse it."
    }

    private func recommendationDetail(
        dueCards: Int,
        newCards: Int,
        totalCards: Int
    ) -> String {
        if dueCards > 0 {
            return "\(dueCards) card\(dueCards == 1 ? "" : "s") due for review"
        }

        if newCards > 0 {
            return "\(newCards) new card\(newCards == 1 ? "" : "s") ready to learn"
        }

        return "\(totalCards) card\(totalCards == 1 ? "" : "s") in this deck"
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
