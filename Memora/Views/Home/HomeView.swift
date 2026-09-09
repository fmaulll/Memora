import SwiftUI
import SwiftData

private enum ProgressFilter: String, CaseIterable {
    case all = "All"
    case due = "Due now"
    case learning = "Learning"
    case new = "New"
    case confirmed = "Confirmed"
    case active = "In progress"
    case today = "Studied today"
    case scheduled = "Scheduled"
}

struct HomeView: View {
    @Query(sort: \StudyDeck.createdAt, order: .reverse) private var decks: [StudyDeck]
    @State private var selectedTab: BottomBar.Tab = .home
    @State private var isShowingNewStudyDeck = false
    @State private var selectedDeck: StudyDeck?
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var filter: ProgressFilter = .all
    @State private var scheduledDate = Date()
    @State private var expandedDecks = Set<UUID>()
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    private let accent = Color.appAccent

    init(initialDeck: StudyDeck? = nil) {
        _selectedTab = State(initialValue: initialDeck == nil ? .home : .library)
        _selectedDeck = State(initialValue: initialDeck)
    }

    private var rootDeckCount: Int { decks.filter { $0.parentDeck == nil && !$0.needsDeletion }.count }
    private var totalCardCount: Int {
        StudyProgressSummary(decks: decks, isSubscribed: subscriptionManager.isSubscribed, now: .now).totalCards
    }

    var body: some View {
        AppBackground {
            Group {
                if selectedTab == .home {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        dashboard(now: timeline.date)
                    }
                } else {
                    LibraryView()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(Color.appBackground.ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(Color.appBorder).frame(height: 1) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(selectedTab: $selectedTab) { isShowingNewStudyDeck = true }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $isShowingNewStudyDeck) {
            NewStudyDeckView(onFinish: { deck in
                isShowingNewStudyDeck = false
                selectedTab = .library
                selectedDeck = deck
            })
        }
        .navigationDestination(item: $selectedDeck) { deck in
            DeckDetailsView(deck: deck)
        }
    }

    private func dashboard(now: Date) -> some View {
        let summary = StudyProgressSummary(decks: decks, isSubscribed: subscriptionManager.isSubscribed, now: now)
        return ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if summary.decks.isEmpty {
                        emptyState
                    } else {
                        overview(summary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            metric("Cards studied today", value: summary.studiedToday, icon: "sun.max", color: .appAccent) {
                                select(.today, proxy: proxy)
                            }
                            metric("Due for review", value: summary.dueCards, icon: "clock", color: .appWarning) {
                                select(.due, proxy: proxy)
                            }
                            metric("Recall confirmed", value: summary.confirmedCards, icon: "checkmark.circle", color: .appSuccess) {
                                select(.confirmed, proxy: proxy)
                            }
                            metric("Decks in progress", value: summary.activeSessions, icon: "play.circle", color: .appInfo) {
                                select(.active, proxy: proxy)
                            }
                        }
                        recommendation(summary)
                        upcomingReviews(summary, now: now, proxy: proxy)
                        deckProgress(summary, now: now)
                            .id("deck-progress")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
    }

    private func select(_ selection: ProgressFilter, proxy: ScrollViewProxy) {
        filter = selection
        withAnimation { proxy.scrollTo("deck-progress", anchor: .top) }
    }

    private func overview(_ summary: StudyProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("YOUR LEARNING")
            Text("\(summary.confirmedCards) of \(summary.totalCards) cards")
                .font(.custom("PlusJakartaSans-ExtraBold", size: 28))
                .foregroundStyle(Color.appTextPrimary)
            Text("Recall confirmed. Keep reviewing to make it stick.")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(Color.appTextSecondary)
            progressBar(confirmed: summary.confirmedCards, learning: summary.learningCards, total: summary.totalCards)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    legend("\(summary.newCards) new", color: .appTextSecondary)
                    legend("\(summary.learningCards) learning", color: .appAccent)
                    legend("\(summary.confirmedCards) confirmed", color: .appSuccess)
                }
                VStack(alignment: .leading, spacing: 8) {
                    legend("\(summary.newCards) new", color: .appTextSecondary)
                    legend("\(summary.learningCards) learning", color: .appAccent)
                    legend("\(summary.confirmedCards) confirmed", color: .appSuccess)
                }
            }
        }
        .padding(20)
        .homePanel()
    }

    private func metric(_ title: String, value: Int, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon).foregroundStyle(color)
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(Color.appTextSecondary)
                }
                .font(.system(size: 14, weight: .semibold))
                Text("\(value)")
                    .font(.custom("PlusJakartaSans-Bold", size: 26))
                    .foregroundStyle(Color.appTextPrimary)
                Text(title)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(minHeight: 32, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .homePanel()
        }
        .buttonStyle(.plain)
    }

    private func recommendation(_ summary: StudyProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("MR. ED'S NEXT STEP")
                    Text(summary.recommended.map {
                        $0.hasActiveSession ? "Unfinished business. Yours."
                        : $0.dueCount > 0 ? "Your memory needs a refresh."
                        : "Knowing the title doesn't count."
                    } ?? "Nothing due. Enjoy the peace. Briefly.")
                        .font(.custom("PlusJakartaSans-Bold", size: 22))
                        .foregroundStyle(Color.appTextPrimary)
                }
                Spacer(minLength: 12)
                Image("MrEdLeaning")
                    .resizable().scaledToFit().frame(width: 72, height: 90)
                    .accessibilityHidden(true)
            }
            if let next = summary.recommended {
                Text(next.deck.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                    .foregroundStyle(Color.appTextPrimary)
                Text(next.hasActiveSession
                     ? "\(next.sessionRemaining) cards left in your saved session."
                     : "\(next.dueCount) due · \(next.learningCount) learning · \(next.newCount) new")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                AppButton(title: next.hasActiveSession ? "Continue in deck" : "Open deck", foreground: Color.appBackground, background: Color.appAccent) {
                    selectedDeck = next.resumeDeck ?? next.deck
                }
            } else {
                Text(summary.decks.allSatisfy(\.isLocked)
                     ? "Your AI decks are locked. Open one below to unlock it, or create your own deck."
                     : "Check your upcoming reviews below, or add something new to learn.")
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                AppButton(title: "Create a deck", foreground: Color.appBackground, background: Color.appAccent) {
                    isShowingNewStudyDeck = true
                }
            }
        }
        .padding(20)
        .homePanel()
    }

    private func upcomingReviews(_ summary: StudyProgressSummary, now: Date, proxy: ScrollViewProxy) -> some View {
        let days = (1...7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: now)) }
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("NEXT 7 DAYS")
            Text("Scheduled cards, based on their current review dates.")
                .font(.custom("PlusJakartaSans-Regular", size: 12))
                .foregroundStyle(Color.appTextSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        let count = summary.decks.reduce(0) { $0 + $1.scheduledCount(on: date) }
                        Button {
                            scheduledDate = date
                            select(.scheduled, proxy: proxy)
                        } label: {
                            VStack(spacing: 8) {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.custom("PlusJakartaSans-Regular", size: 11))
                                Text("\(count)")
                                    .font(.custom("PlusJakartaSans-Bold", size: 22))
                                    .foregroundStyle(count > 0 ? Color.appAccent : Color.appTextSecondary)
                                Text(date, format: .dateTime.day().month(.abbreviated))
                                    .font(.custom("PlusJakartaSans-Regular", size: 10))
                            }
                            .foregroundStyle(Color.appTextSecondary)
                            .frame(width: 66)
                            .padding(.vertical, 14)
                            .homePanel()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)), \(count) scheduled cards")
                    }
                }
            }
        }
    }

    private func deckProgress(_ summary: StudyProgressSummary, now: Date) -> some View {
        let visible = summary.decks.filter(matchesFilter)
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("EVERY DECK, EVERY STEP")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProgressFilter.allCases.filter { $0 != .scheduled }, id: \.self) { option in
                        Button { filter = option } label: {
                            Text(option.rawValue)
                                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                                .foregroundStyle(filter == option ? Color.appBackground : Color.appTextSecondary)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(filter == option ? Color.appAccent : Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if filter == .scheduled {
                Text("Reviews on \(scheduledDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundStyle(Color.appAccent)
            }
            if visible.isEmpty {
                Text("No decks match this view yet. Choose All to see your full collection.")
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundStyle(Color.appTextSecondary)
                    .padding(16)
                    .homePanel()
            }
            ForEach(visible) { progress in
                VStack(spacing: 0) {
                    deckRow(progress)
                    if !progress.descendants.isEmpty {
                        Button {
                            if !expandedDecks.insert(progress.id).inserted { expandedDecks.remove(progress.id) }
                        } label: {
                            HStack {
                                Text("\(expandedDecks.contains(progress.id) ? "Hide" : "Show") \(progress.descendants.count) chapters")
                                Spacer()
                                Image(systemName: expandedDecks.contains(progress.id) ? "chevron.up" : "chevron.down")
                            }
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                            .foregroundStyle(Color.appAccent)
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                        if expandedDecks.contains(progress.id) {
                            ForEach(progress.descendants) { child in
                                Rectangle().fill(Color.appBorder).frame(height: 1)
                                deckRow(DeckProgressSummary(deck: child, isSubscribed: subscriptionManager.isSubscribed, now: now))
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
                .homePanel()
            }
        }
    }

    private func matchesFilter(_ deck: DeckProgressSummary) -> Bool {
        switch filter {
        case .all: return true
        case .due: return deck.dueCount > 0
        case .learning: return deck.learningCount > 0
        case .new: return deck.newCount > 0
        case .confirmed: return deck.confirmedCount > 0
        case .active: return !deck.isLocked && deck.hasActiveSession
        case .today: return deck.studiedTodayCount > 0
        case .scheduled: return deck.scheduledCount(on: scheduledDate) > 0
        }
    }

    private func deckRow(_ progress: DeckProgressSummary) -> some View {
        Button { selectedDeck = progress.deck } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: progress.isLocked ? "lock.fill" : "rectangle.stack")
                        .foregroundStyle(Color.appAccent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(progress.deck.title)
                            .font(.custom("PlusJakartaSans-Bold", size: 16))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("\(progress.confirmedCount)/\(progress.totalCount) recall confirmed")
                            .font(.custom("PlusJakartaSans-Regular", size: 12))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Color.appTextSecondary)
                }
                progressBar(confirmed: progress.confirmedCount, learning: progress.learningCount, total: progress.totalCount)
                Text("\(progress.newCount) new · \(progress.learningCount) learning · \(progress.dueCount) due")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                if progress.isLocked {
                    rowNote("Locked · open to unlock", color: .appWarning)
                } else if progress.hasGenerationFailure {
                    rowNote("Generation needs attention · open deck", color: .appError)
                } else if progress.isGenerating {
                    rowNote("Building your cards…", color: .appAccent)
                } else if progress.hasActiveSession {
                    rowNote("Session: \(max(0, progress.sessionTotal - progress.sessionRemaining))/\(progress.sessionTotal) cards checked", color: .appInfo)
                } else if let next = progress.nextReviewAt, progress.dueCount == 0 {
                    rowNote("Next review: \(next.formatted(date: .abbreviated, time: .shortened))", color: .appTextSecondary)
                }
                if let last = progress.lastStudiedAt {
                    rowNote("Last studied: \(last.formatted(date: .abbreviated, time: .shortened))", color: .appTextSecondary)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private func rowNote(_ text: String, color: Color) -> some View {
        Text(text).font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(color)
    }

    private func progressBar(confirmed: Int, learning: Int, total: Int) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Color.appSuccess.frame(width: total == 0 ? 0 : geometry.size.width * CGFloat(confirmed) / CGFloat(total))
                Color.appAccent.frame(width: total == 0 ? 0 : geometry.size.width * CGFloat(learning) / CGFloat(total))
                Color.appBorder
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("\(confirmed) confirmed, \(learning) learning, \(max(0, total - confirmed - learning)) new cards")
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.custom("PlusJakartaSans-Regular", size: 11)).foregroundStyle(Color.appTextSecondary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.custom("PlusJakartaSans-Bold", size: 11)).foregroundStyle(Color.appTextSecondary)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("MR. ED'S VERDICT")
            Text("No deck. No progress.\nLet's change that.")
                .font(.custom("PlusJakartaSans-ExtraBold", size: 28))
                .foregroundStyle(Color.appTextPrimary)
            Text("Create a deck, study its cards, and watch your progress grow here.")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(Color.appTextSecondary)
            AppButton(title: "Create a deck", foreground: Color.appBackground, background: Color.appAccent) {
                isShowingNewStudyDeck = true
            }
        }
        .padding(20)
        .homePanel()
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
                settingsButton
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("\(rootDeckCount) decks · \(totalCardCount) cards")
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
                        .padding(.vertical, 4)
                }
                .accessibilityLabel("Create a new study deck")
            }
        }
    }

    private var settingsButton: some View {
        NavigationLink { SettingsView() } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 44, height: 44)
                .settingsPanel()
        }
        .accessibilityLabel("Settings")
    }

}

private extension View {
    func homePanel() -> some View {
        self.background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
