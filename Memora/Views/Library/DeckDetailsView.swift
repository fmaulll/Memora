import SwiftUI

struct DeckDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: StudyDeck

    @State private var isShowingMoveDeck = false
    @State private var isShowingCreateSubDeck = false
    @State private var isShowingEditDeck = false
    @State private var isShowingEditCards = false
    @State private var isShowingMoreOptions = false
    @State private var isShowingResetConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingCreateWithAI = false

    @State private var isAnswerRevealed = false
    @State private var currentCardIndex = 0

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let cardFill = Color.white.opacity(0.18)

    private var totalCards: Int {
        deck.cards.filter { !$0.needsDeletion }.count
    }

    private var masteredCards: Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.correctCount > 0
        }.count
    }

    private var learningCards: Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.reviewCount > 0 &&
            $0.correctCount == 0
        }.count
    }

    private var newCards: Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.reviewCount == 0
        }.count
    }

    private var masteryProgress: Double {
        guard totalCards > 0 else { return 0 }

        return Double(masteredCards) / Double(totalCards)
    }

    private var availableCards: [StudyFlashcardCard] {
        deck.cards.filter { !$0.needsDeletion }
    }

    private var childDecks: [StudyDeck] {
        deck.childDecks
            .filter { !$0.needsDeletion }
            .sorted {
                $0.createdAt < $1.createdAt
            }
    }

    private var allChildCards: [StudyFlashcardCard] {
        childDecks
            .flatMap(\.cards)
            .filter { !$0.needsDeletion }
    }

    private var isParentDeck: Bool {
        !childDecks.isEmpty
    }

    private var hasCards: Bool {
        !availableCards.isEmpty
    }

    private var canCreateSubDeck: Bool {
        deck.parentDeck == nil && !hasCards
    }

    private var totalStudyCards: Int {
        if isParentDeck {
            return allChildCards.count
        }

        return totalCards
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Flashcard Carousel

                    // MARK: Main Content

                    if isParentDeck {
                        childDeckSection
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                    } else {
                        flashcardCarousel
                            .padding(.top, 20)
                    }

                    // MARK: Deck Information

                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Study All Button

                        if isParentDeck && !allChildCards.isEmpty {
                            NavigationLink {
                                StudyFlashcardsView(decks: childDecks)
                            } label: {
                                HStack(spacing: 10) {

                                    Image(systemName: "play.fill")
                                        .font(.system(size: 15, weight: .bold))

                                    Text(
                                        hasStudyAllProgress
                                            ? "Continue Study"
                                            : "Study All"
                                    )
                                    .font(
                                        .custom(
                                            "PlusJakartaSans-SemiBold",
                                            size: 15
                                        )
                                    )
                                    .foregroundStyle(.white)

                                    Spacer()

                                    Text(
                                        hasStudyAllProgress
                                            ? "\(studyAllCompletedCards) / \(allChildCards.count)"
                                            : "\(allChildCards.count) cards"
                                    )
                                    .font(
                                        .custom(
                                            "PlusJakartaSans-Regular",
                                            size: 12
                                        )
                                    )
                                    .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .contentShape(Rectangle())
                                .background(
                                    LinearGradient(
                                        colors: [
                                            accent,
                                            Color(red: 0.55, green: 0.36, blue: 0.96)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 28)
                        }

                        header
                            .padding(.top, 28)

                        if !isParentDeck {
                            progressSummary
                                .padding(.top, 28)
                        }

                        if !isParentDeck {
                            studyButton
                                .padding(.top, 24)
                        }

                        if !isParentDeck {
                            cardsSection
                                .padding(.top, 28)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BackNavigationBar {
                    deckMoreOptionButton
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()

        .navigationDestination(
            isPresented: $isShowingMoveDeck
        ) {
            MoveDeckView(deck: deck)
        }

        .navigationDestination(isPresented: $isShowingCreateSubDeck) {
            CreateOwnDeckView(
                mode: .empty,
                parentDeck: deck,
                onFinish: { _ in
                    isShowingCreateSubDeck = false
                }
            )
        }

        // MARK: More Options

        .sheet(isPresented: $isShowingMoreOptions) {
            DeckOptionsSheet(
                deck: deck,
                isParentDeck: isParentDeck,
                canCreateSubDeck: canCreateSubDeck,
                onEditDeck: {
                    isShowingMoreOptions = false
                    isShowingEditDeck = true
                },
                onCreateSubDeck: {
                    isShowingMoreOptions = false
                    isShowingCreateSubDeck = true
                },
                onCreateWithAI: {
                    isShowingMoreOptions = false
                    isShowingCreateWithAI = true
                },
                onMoveDeck: {
                    isShowingMoreOptions = false
                    isShowingMoveDeck = true
                },
                onManageCards: {
                    isShowingMoreOptions = false
                    isShowingEditCards = true
                },
                onResetProgress: {
                    isShowingMoreOptions = false
                    isShowingResetConfirmation = true
                },
                onDeleteDeck: {
                    isShowingMoreOptions = false
                    isShowingDeleteConfirmation = true
                }
            )
            .presentationDetents([.fraction(0.67)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
        }

        .alert(
            "Reset Progress?",
            isPresented: $isShowingResetConfirmation
        ) {
            Button("Cancel", role: .cancel) { }

            Button("Reset", role: .destructive) {
                resetProgress()
            }
        } message: {
            if isParentDeck {
                Text(
                    "This will reset the learning progress of all \(childDecks.count) sub-decks and their cards. Your cards will not be deleted."
                )
            } else {
                Text(
                    "This will reset all learning progress for this deck. Your cards will not be deleted."
                )
            }
        }

        .alert(
            "Delete Deck?",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }

            Button("Delete", role: .destructive) {
                deleteDeck()
            }
        } message: {
            if isParentDeck {
                Text(
                    "\"\(deck.title)\" contains \(childDecks.count) sub-decks and \(allChildCards.count) flashcards. All of them will be deleted."
                )
            } else {
                Text(
                    "\"\(deck.title)\" and its \(totalCards) flashcards will be deleted."
                )
            }
        }

        // MARK: Navigation

        .navigationDestination(isPresented: $isShowingEditDeck) {
            CreateOwnDeckView(existingDeck: deck)
        }

        .navigationDestination(isPresented: $isShowingEditCards) {
            AddFlashcardView(
                deck: deck,
                isEditMode: true
            )
        }
        .navigationDestination(isPresented: $isShowingCreateWithAI) {
            AIDeckSetupView(
                onDeckCreated: { createdDeck in
                    isShowingCreateWithAI = false

                    print(
                        "✅ AI SUB-DECK CREATED:",
                        createdDeck.title
                    )
                },
                parentDeck: deck
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text(deck.title)
                .font(
                    .custom(
                        "PlusJakartaSans-ExtraBold",
                        size: 28
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 8) {

                Text(deck.subject.uppercased())
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 11
                        )
                    )
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        accent.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                Text(
                    isParentDeck
                        ? "\(deck.educationLevel) • \(childDecks.count) decks • \(totalStudyCards) cards"
                        : "\(deck.educationLevel) • \(totalStudyCards) card\(totalStudyCards == 1 ? "" : "s")"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 13
                    )
                )
                .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var deckMoreOptionButton: some View {

        Button {
            isShowingMoreOptions = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options for deck \(deck.title)")

    }

    private func deleteDeck() {
        let decksToDelete: [StudyDeck]

        if isParentDeck {
            decksToDelete = [deck] + childDecks
        } else {
            decksToDelete = [deck]
        }

        // Mark every card for deletion first
        for targetDeck in decksToDelete {
            for card in targetDeck.cards {
                card.needsDeletion = true
                card.syncState = SyncManager.CardSyncState.deleted
            }

            // Mark the deck for deletion
            targetDeck.needsDeletion = true
        }

        do {
            try modelContext.save()

            print("========== DECK MARKED FOR DELETION ==========")
            print("DECKS:", decksToDelete.count)

            for targetDeck in decksToDelete {
                print(
                    "🗑️",
                    targetDeck.title,
                    "-",
                    targetDeck.cards.count,
                    "cards"
                )
            }

            dismiss()

        } catch {
            print("❌ FAILED TO MARK DECK FOR DELETION:", error)
        }
    }

    private func resetProgress() {
        let decksToReset: [StudyDeck]

        if isParentDeck {
            decksToReset = childDecks
        } else {
            decksToReset = [deck]
        }

        for targetDeck in decksToReset {

            // Reset every card's spaced-repetition progress
            for card in targetDeck.cards where !card.needsDeletion {
                card.reviewCount = 0
                card.correctCount = 0
                card.lastReviewedAt = nil
                card.nextReviewAt = nil
                card.difficulty = 0.0
                card.interval = 0
            }

            // Reset normal study session
            targetDeck.studyQueueIDs = []
            targetDeck.learningQueueIDs = []
            targetDeck.studyCompletedCount = 0
            targetDeck.isStudySessionActive = false

            // Reset Study All session
            targetDeck.studyAllQueueIDs = []
            targetDeck.studyAllLearningQueueIDs = []
            targetDeck.studyAllCompletedCount = 0
            targetDeck.isStudyAllSessionActive = false
        }

        do {
            try modelContext.save()

            print("========== PROGRESS RESET ==========")
            print("DECK:", deck.title)
            print("RESET DECKS:", decksToReset.count)

        } catch {
            print("❌ RESET PROGRESS ERROR:", error)
        }
    }

    // MARK: Reveal

    private func revealAnswer() {
        guard !isAnswerRevealed else {
            withAnimation(.easeInOut(duration: 0.25)) {
                isAnswerRevealed = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            isAnswerRevealed = true
        }
    }

    private var flashcardCarousel: some View {
        VStack(spacing: 12) {

            if hasCards {

                TabView(selection: $currentCardIndex) {
                    ForEach(
                        Array(availableCards.enumerated()),
                        id: \.element.persistentModelID
                    ) { index, card in

                        FlashcardView(
                            card: card,
                            isAnswerRevealed: isAnswerRevealed
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            revealAnswer()
                        }
                        .tag(index)
                        .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 315)
                .onChange(of: availableCards.count) {
                    if availableCards.isEmpty {
                        currentCardIndex = 0
                        isAnswerRevealed = false
                    } else if currentCardIndex >= availableCards.count {
                        currentCardIndex = max(
                            availableCards.count - 1,
                            0
                        )
                    }
                }

                HStack(spacing: 6) {
                    ForEach(
                        0..<availableCards.count,
                        id: \.self
                    ) { index in

                        Capsule()
                            .fill(
                                index == currentCardIndex
                                    ? accent
                                    : .white.opacity(0.12)
                            )
                            .frame(
                                width: index == currentCardIndex ? 18 : 6,
                                height: 6
                            )
                            .animation(
                                .easeInOut(duration: 0.2),
                                value: currentCardIndex
                            )
                    }
                }
                .frame(maxWidth: .infinity)

            } else {
                emptyFlashcardState
            }
        }
        .onChange(of: currentCardIndex) {
            isAnswerRevealed = false
        }
    }

    private var emptyFlashcardState: some View {
        VStack(spacing: 14) {

            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(accent)

            Text("No flashcards yet")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 17
                    )
                )
                .foregroundStyle(.white)

            Text("Add some flashcards to start studying this deck.")
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 13
                    )
                )
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                isShowingEditCards = true
            } label: {
                Text("Add Flashcards")
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 13
                        )
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        accent,
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 265)
        .padding(.horizontal, 24)
        .background(
            Color.white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    .white.opacity(0.16),
                    lineWidth: 1
                )
        }
        .padding(.horizontal, 20)
    }

    private func masteredCount(for deck: StudyDeck) -> Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.correctCount > 0
        }.count
    }

    private var childDeckSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack {
                Text("Study Decks")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 17
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                Text("\(childDecks.count)")
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 13
                        )
                    )
                    .foregroundStyle(accent)
            }

            ForEach(childDecks) { childDeck in

                NavigationLink {
                    DeckDetailsView(deck: childDeck)
                } label: {
                    HStack(spacing: 14) {

                        VStack(
                            alignment: .leading,
                            spacing: 5
                        ) {
                            Text(childDeck.title)
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 15
                                    )
                                )
                                .foregroundStyle(.white)

                            Text(
                                "\(childDeck.totalCardCount) cards"
                                + (masteredCount(for: childDeck) > 0
                                    ? " · \(masteredCount(for: childDeck)) mastered"
                                    : "")
                            )
                            .font(
                                .custom(
                                    "PlusJakartaSans-Regular",
                                    size: 12
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.5)
                            )
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.3)
                            )
                    }
                    .padding(16)
                    .background(
                        Color.white.opacity(0.055),
                        in: RoundedRectangle(
                            cornerRadius: 16
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 16
                        )
                        .stroke(
                            .white.opacity(0.12),
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private struct FlashcardView: View {
        let card: StudyFlashcardCard
        let isAnswerRevealed: Bool

        var body: some View {
            VStack(spacing: 0) {

                Text(card.front)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 22))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)


                if isAnswerRevealed {
                    Divider()
                        .overlay(.white.opacity(0.10))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 28)

                    Text(card.back)
                        .font(.custom("PlusJakartaSans-Regular", size: 17))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(
                            .opacity
                            .combined(with: .move(edge: .bottom))
                        )
                }

            }
            .frame(maxWidth: .infinity)
            .frame(height: 265)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(
                Color.white.opacity(0.055),
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        .white.opacity(0.16),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    
                } label: {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 24, weight: .medium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View card \(card.front) in deck")
                .padding(20)
            }
        }
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Mastery completed")
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 13
                        )
                    )
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Text("\(masteredCards) / \(totalCards) Mastered")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 13
                        )
                    )
                    .foregroundStyle(accent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(accent)
                        .frame(
                            width: geometry.size.width * masteryProgress
                        )
                }
            }
            .frame(height: 6)

            HStack(spacing: 8) {

                progressPill(
                    title: "Mastered",
                    count: masteredCards,
                    color: .green
                )

                progressPill(
                    title: "Learning",
                    count: learningCards,
                    color: .orange
                )

                progressPill(
                    title: "New",
                    count: newCards,
                    color: .white.opacity(0.35)
                )

                Spacer()
            }
        }
    }

    private func progressPill(
        title: String,
        count: Int,
        color: Color
    ) -> some View {

        HStack(spacing: 6) {

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 12
                    )
                )
                .foregroundStyle(.white.opacity(0.6))

            Text("\(count)")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 12
                    )
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            .white.opacity(0.045),
            in: Capsule()
        )
    }

    private var studyAllCompletedCards: Int {
        childDecks.reduce(0) {
            $0 + $1.studyAllCompletedCount
        }
    }

    private var hasStudyAllProgress: Bool {
        childDecks.contains {
            $0.isStudyAllSessionActive
        }
    }

    private var studyButton: some View {
        NavigationLink {
            StudyFlashcardsView(deck: deck)
        } label: {
            Label("Study Flashcards", systemImage: "play.fill")
                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [
                            accent,
                            Color(red: 0.55, green: 0.36, blue: 0.96)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
    }

    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.28), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {

                Text("Cards")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 17
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    isShowingEditCards = true
                } label: {
                    Text("Manage List")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 13
                            )
                        )
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            flashcardList
                .padding(.top, 12)
        }
    }

    private var flashcardList: some View {
        VStack(spacing: 12) {

            ForEach(
                Array(
                    deck.cards
                        .filter { !$0.needsDeletion }
                        .enumerated()
                ),
                id: \.element.persistentModelID
            ) { index, card in

                flashcardRow(
                    number: index + 1,
                    card: card
                )
            }
        }
    }

    private func flashcardRow(
        number: Int,
        card: StudyFlashcardCard
    ) -> some View {

        HStack(spacing: 14) {

            Text(String(format: "%02d", number))
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.35)
                )
                .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(card.front)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(2)

                cardStatus(card)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    .white.opacity(0.25)
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            
            Color.white.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    .white.opacity(0.16),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private func cardStatus(
        _ card: StudyFlashcardCard
    ) -> some View {

        if card.reviewCount == 0 {

            Label("New", systemImage: "circle")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.4)
                )

        } else if card.interval < 7 {

            Label("Learning", systemImage: "arrow.triangle.2.circlepath")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(.orange)

        } else {

            Label("Mastered", systemImage: "checkmark.circle.fill")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    let deck = StudyDeck(title: "Cell Division & Mitosis", subject: "Biology", educationLevel: "University")
    deck.cards = [StudyFlashcardCard(front: "What is mitosis?", back: "Cell division producing two identical cells")]
    return NavigationStack {
        DeckDetailsView(deck: deck)
    }
}
