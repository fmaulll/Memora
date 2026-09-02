import SwiftUI

enum AIDeckAction {
    case createDeck
    case generateCards
    case generateMoreCards
}

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

    @State private var generationPollingTask: Task<Void, Never>?
    @State private var isPollingGeneration = false

    private let accent = Color.appAccent

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
        deck.parentDeck == nil
        && !hasCards
    }

    private var canCreateWithAI: Bool {
        deck.parentDeck == nil
        && !hasCards
        && deck.childDecks.isEmpty
    }

    private var totalStudyCards: Int {
        if isParentDeck {
            return allChildCards.count
        }

        return totalCards
    }

    private var aiDeckAction: AIDeckAction? {
        let hasCards = !deck.cards.filter { !$0.needsDeletion }.isEmpty
        let isRoot = deck.parentDeck == nil
        let hasChildren = !deck.childDecks.isEmpty

        if hasCards {
            return .generateMoreCards
        }

        if isRoot && !hasChildren {
            return .createDeck
        }

        if !isRoot {
            return .generateCards
        }

        return nil
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
                            .padding(.horizontal, 24)
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
                                    .foregroundStyle(Color.appTextPrimary)

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
                                    .foregroundStyle(Color.appTextSecondary)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .contentShape(Rectangle())
                                .background(
                                    Color.appAccent,
                                    in: RoundedRectangle(cornerRadius: 8)
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
                    .padding(.horizontal, 24)
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
                canCreateWithAI: canCreateWithAI,
                aiDeckAction: aiDeckAction,
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
                },
                onGenerateCardsWithAI: {
                    print("🤖 GENERATE CARDS FOR DECK")
                },

                onGenerateMoreCardsWithAI: {
                    print("🤖 GENERATE MORE CARDS")
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
                existingDeck: deck
            )
        }
        .task {
            startGenerationPollingIfNeeded()
        }
        .onDisappear {
            stopGenerationPolling()
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
                .foregroundStyle(Color.appTextPrimary)
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
                .foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private var deckMoreOptionButton: some View {

        Button {
            isShowingMoreOptions = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: 40, height: 40)
                .background(Color.appSurface, in: Circle())
                .overlay {
                    Circle().stroke(Color.appBorder, lineWidth: 1)
                }
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

    // MARK: - AI Generation Polling

    private func startGenerationPollingIfNeeded() {
        guard deck.parentDeck == nil else {
            return
        }

        guard deck.generationStatus == "generating" else {
            return
        }

        guard generationPollingTask == nil else {
            return
        }

        isPollingGeneration = true

        generationPollingTask = Task {
            await pollGenerationStatus()
        }
    }


    private func stopGenerationPolling() {
        generationPollingTask?.cancel()
        generationPollingTask = nil
        isPollingGeneration = false
    }


    private func pollGenerationStatus() async {

        while !Task.isCancelled {

            do {
                let status = try await AIService.shared
                    .fetchGenerationStatus(deckID: deck.id)

                let chaptersToSync = await MainActor.run {
                    () -> [UUID] in

                    deck.generationStatus = status.generationStatus

                    var completedIDs: [UUID] = []

                    for chapterStatus in status.chapters {

                        guard let localChapter = deck.childDecks.first(
                            where: { $0.id == chapterStatus.id }
                        ) else {
                            continue
                        }

                        let previousStatus =
                            localChapter.generationStatus

                        localChapter.generationStatus =
                            chapterStatus.generationStatus

                        if previousStatus != "completed"
                            && chapterStatus.generationStatus == "completed" {

                            completedIDs.append(chapterStatus.id)
                        }
                    }

                    try? modelContext.save()

                    return completedIDs
                }

                // Download ONLY newly completed chapters
                for chapterID in chaptersToSync {

                    do {
                        try await SyncManager.shared.downloadDeck(
                            id: chapterID,
                            modelContext: modelContext
                        )
                    } catch {
                        print(
                            "❌ FAILED TO DOWNLOAD CHAPTER:",
                            chapterID,
                            error
                        )
                    }
                }

                // Stop when backend says everything is completed
                if status.generationStatus == "completed" {

                    isPollingGeneration = false
                    generationPollingTask = nil

                    break
                }

            } catch is CancellationError {

                break

            } catch {

                print(
                    "❌ GENERATION POLLING ERROR:",
                    error
                )
            }

            do {

                try await Task.sleep(
                    for: .seconds(3)
                )

            } catch {

                break
            }
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
                                    : Color.appBorder
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
                .foregroundStyle(Color.appTextPrimary)

            Text("Add some flashcards to start studying this deck.")
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 13
                    )
                )
                .foregroundStyle(Color.appTextSecondary)
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
                    .foregroundStyle(Color.appTextPrimary)
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
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .padding(.horizontal, 24)
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
                    .foregroundStyle(Color.appTextPrimary)

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

                if childDeck.generationStatus == "completed" {

                    NavigationLink {
                        DeckDetailsView(deck: childDeck)
                    } label: {
                        childDeckRow(childDeck)
                    }
                    .buttonStyle(.plain)

                } else {

                    childDeckRow(childDeck)
                        .opacity(0.6)
                }
            }
        }
    }

    private func childDeckRow(
        _ childDeck: StudyDeck
    ) -> some View {

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
                    .foregroundStyle(Color.appTextPrimary)

                generationStatusText(
                    for: childDeck
                )
            }

            Spacer()

            if childDeck.generationStatus == "completed" {

                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.appTextSecondary
                    )

            } else {

                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.appTextSecondary)
            }
        }
        .padding(16)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
        private func generationStatusText(
            for childDeck: StudyDeck
        ) -> some View {

            switch childDeck.generationStatus {

            case "completed":

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
                    Color.appTextSecondary
                )

            case "generating":

                Label(
                    "Generating cards...",
                    systemImage: "sparkles"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 12
                    )
                )
                .foregroundStyle(accent)

            default:

                Label(
                    "Waiting to generate...",
                    systemImage: "clock"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 12
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
            }
        }
    
    private struct FlashcardView: View {
        let card: StudyFlashcardCard
        let isAnswerRevealed: Bool

        var body: some View {
            VStack(spacing: 0) {

                Text(card.front)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 22))
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)


                if isAnswerRevealed {
                    Divider()
                        .overlay(Color.appBorder)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 28)

                    Text(card.back)
                        .font(.custom("PlusJakartaSans-Regular", size: 17))
                        .foregroundStyle(Color.appTextSecondary)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
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
                    .foregroundStyle(Color.appTextSecondary)

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
                        .fill(Color.appSecondarySurface)

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
                    color: Color.appSuccess
                )

                progressPill(
                    title: "Learning",
                    count: learningCards,
                    color: Color.appWarning
                )

                progressPill(
                    title: "New",
                    count: newCards,
                    color: Color.appTextSecondary
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
                .foregroundStyle(Color.appTextSecondary)

            Text("\(count)")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 12
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.appSecondarySurface, in: Capsule())
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
                .foregroundStyle(Color.appTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Color.appAccent,
                    in: RoundedRectangle(cornerRadius: 8)
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
                    .foregroundStyle(Color.appTextPrimary)

                Text(subtitle)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
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
                    .foregroundStyle(Color.appTextPrimary)

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
                    Color.appTextSecondary
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
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                cardStatus(card)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    Color.appTextSecondary
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
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
                    Color.appTextSecondary
                )

        } else if card.interval < 7 {

            Label("Learning", systemImage: "arrow.triangle.2.circlepath")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(Color.appWarning)

        } else {

            Label("Mastered", systemImage: "checkmark.circle.fill")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(Color.appSuccess)
        }
    }

    private func completedChapterIDs(
        from status: DeckGenerationStatusResponse
    ) -> [UUID] {

        status.chapters.compactMap { chapterStatus in

            guard chapterStatus.generationStatus == "completed" else {
                return nil
            }

            guard let localChapter = deck.childDecks.first(
                where: { $0.id == chapterStatus.id }
            ) else {
                return nil
            }

            // Already downloaded
            guard localChapter.cards.isEmpty else {
                return nil
            }

            return chapterStatus.id
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
