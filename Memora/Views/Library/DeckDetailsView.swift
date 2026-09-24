import SwiftUI

enum AIDeckAction {
    case createDeck
    case generateCards
    case generateMoreCards
}

private enum ExamFeatureError: LocalizedError {
    case emptyQuestions

    var errorDescription: String? {
        "This exam did not return any questions. Please try again."
    }
}

private enum ContentSection {
    case cards
    case exams
}

private enum StudyScope {
    case chapter
    case all
}

// Gate both the root deck and direct chapter navigation before exposing cards,
// exams, editing, moving, or study actions.
struct DeckDetailsView: View {
    let deck: StudyDeck
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var isShowingPaywall = false

    var body: some View {
        Group {
            if deck.needsSubscription && !subscriptionManager.isSubscribed {
                AppBackground {
                    VStack(spacing: 24) {
                        Spacer()
                        Image("MrEdJudging")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.appAccent)
                        Text(deck.title)
                            .font(.custom("PlusJakartaSans-Bold", size: 28))
                        Text("Your deck is saved. Subscribe to unlock its flashcards and exams. Mr. Ed already did his part.")
                            .foregroundStyle(Color.appTextSecondary)
                        AppButton(title: "Unlock my deck") {
                            isShowingPaywall = true
                        }
                        Spacer()
                    }
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        BackNavigationBar { EmptyView() }
                    }
                }
                .navigationBarBackButtonHidden()
            } else {
                UnlockedDeckDetailsView(deck: deck)
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(
                onSubscribed: { isShowingPaywall = false },
                onContinueFree: { isShowingPaywall = false },
                deckTitle: deck.title
            )
        }
    }
}

private struct UnlockedDeckDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let deck: StudyDeck

    @State private var isShowingReorderChapters = false
    @State private var isShowingCreateSubDeck = false
    @State private var isShowingEditDeck = false
    @State private var isShowingEditChapter = false
    @State private var deckToManageCards: StudyDeck?
    @State private var deckToMove: StudyDeck?
    @State private var deckToReset: StudyDeck?
    @State private var deckToDelete: StudyDeck?
    @State private var isShowingEditCards = false
    @State private var isShowingMoreOptions = false
    @State private var isShowingResetConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingCreateWithAI = false

    @State private var selectedChapterID: UUID?
    @State private var isShowingChapterPicker = false
    @State private var isAnswerRevealed = false
    @State private var currentCardIndex = 0

    @State private var generationPollingTask: Task<Void, Never>?
    @State private var isPollingGeneration = false
    @State private var isRetryingGeneration = false
    @State private var retryErrorMessage: String?
    @State private var examProgression: ExamProgressionResponse?
    @State private var isLoadingExams = false
    @State private var examErrorMessage: String?
    @State private var isGeneratingExam = false
    @State private var generatingExamType: ExamType?
    @State private var examQuestionsResponse: ExamQuestionsResponse?
    @State private var isShowingExam = false

    @State private var selectedContentSection: ContentSection = .cards
    @State private var selectedStudyScope: StudyScope = .chapter

    private let accent = Color.appAccent

    private var totalCards: Int {
        availableCards.count
    }

    private var masteredCards: Int {
        availableCards.filter {
            $0.correctCount > 0
        }.count
    }

    private var learningCards: Int {
        availableCards.filter {
            $0.reviewCount > 0 &&
            $0.correctCount == 0
        }.count
    }

    private var newCards: Int {
        availableCards.filter {
            $0.reviewCount == 0
        }.count
    }

    private var masteryProgress: Double {
        guard totalCards > 0 else { return 0 }

        return Double(masteredCards) / Double(totalCards)
    }

    private var availableCards: [StudyFlashcardCard] {
        displayedDeck.cards.filter {
            !$0.needsDeletion
        }
    }

    private var childDecks: [StudyDeck] {
        deck.childDecks
            .filter { !$0.needsDeletion }
            .sorted { lhs, rhs in
                switch (lhs.position, rhs.position) {
                case let (lhsPosition?, rhsPosition?):
                    if lhsPosition != rhsPosition {
                        return lhsPosition < rhsPosition
                    }

                    return lhs.title.localizedCaseInsensitiveCompare(
                        rhs.title
                    ) == .orderedAscending

                case (.some, .none):
                    return true

                case (.none, .some):
                    return false

                case (.none, .none):
                    return lhs.title.localizedCaseInsensitiveCompare(
                        rhs.title
                    ) == .orderedAscending
                }
            }
    }

    private var selectedChapter: StudyDeck? {
        guard isParentDeck else {
            return nil
        }

        if let selectedChapterID,
        let chapter = childDecks.first(
                where: { $0.id == selectedChapterID }
        ) {
            return chapter
        }

        return childDecks.first
    }

    private var displayedDeck: StudyDeck {
        selectedChapter ?? deck
    }

    private var displayedDeckParentTitle: String? {
        guard let parent = displayedDeck.parentDeck else {
            return nil
        }

        return parent.title
    }

    private var allChildCards: [StudyFlashcardCard] {
        childDecks
            .flatMap(\.cards)
            .filter { !$0.needsDeletion }
    }

    private var isParentDeck: Bool {
        !childDecks.isEmpty
    }

    private var isDeckGenerationInProgress: Bool {
        deck.generationStatus == "generating" ||
        childDecks.contains { $0.generationStatus == "generating" }
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
        && childDecks.isEmpty
    }

    private var totalStudyCards: Int {
        if isParentDeck {
            return allChildCards.count
        }

        return totalCards
    }

    private var aiDeckAction: AIDeckAction? {
        let isRoot = deck.parentDeck == nil
        let hasChildren = !childDecks.isEmpty

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

                    if isParentDeck {
                        chapterSelector
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // MARK: Flashcard Carousel

                    // MARK: Main Content
                    if !isParentDeck || selectedChapter != nil {
                        flashcardCarousel
                            .padding(.top, 16)
                    }

                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Deck Information

                        if !isParentDeck || selectedChapter != nil {
                            deckIdentitySection
                                .padding(.top, 16)
                        }

                        contentSectionToggle
                            .padding(.top, 20)
                            .padding(.bottom, 20)

                        if selectedContentSection == .cards {
                            cardsSection
                        } else {
                            examSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

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

        .sheet(
            item: $deckToMove
        ) { deckToMove in
            MoveDeckView(
                deck: deckToMove
            )
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(.visible)
        }

        .sheet(isPresented: $isShowingReorderChapters) {
            ReorderChaptersView(parentDeck: deck)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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

        .sheet(
            isPresented: $isShowingChapterPicker
        ) {
            ChapterPickerSheet(
                chapters: childDecks,
                selectedChapterID: selectedChapter?.id
            ) { chapter in
                selectedChapterID = chapter.id

                currentCardIndex = 0
                isAnswerRevealed = false
            }
            .presentationDetents([
                .medium,
                .large
            ])
            .presentationDragIndicator(.visible)
        }

        // MARK: More Options

        .sheet(isPresented: $isShowingMoreOptions) {
            DeckOptionsSheet(
                deck: deck,
                isParentDeck: isParentDeck,
                canCreateSubDeck: canCreateSubDeck,
                canCreateWithAI: canCreateWithAI,
                selectedChapter: selectedChapter,
                aiDeckAction: aiDeckAction,
                onEditDeck: {
                    isShowingMoreOptions = false
                    isShowingEditDeck = true
                },
                onEditChapter: {
                    isShowingMoreOptions = false
                    isShowingEditChapter = true
                },
                onCreateSubDeck: {
                    isShowingMoreOptions = false
                    isShowingCreateSubDeck = true
                },
                onMoveChapter: {
                    isShowingMoreOptions = false

                    guard let selectedChapter else {
                        return
                    }

                    deckToMove = selectedChapter
                },
                onReorderChapter: {
                    isShowingMoreOptions = false
                    isShowingReorderChapters = true
                },
                onResetChapterProgress: {
                    isShowingMoreOptions = false

                    guard let selectedChapter else {
                        return
                    }

                    deckToReset = selectedChapter
                    isShowingResetConfirmation = true
                },
                onDeleteChapter: {
                    isShowingMoreOptions = false

                    guard let selectedChapter else {
                        return
                    }

                    deckToDelete = selectedChapter
                    isShowingDeleteConfirmation = true
                },
                onCreateWithAI: {
                    isShowingMoreOptions = false
                    isShowingCreateWithAI = true
                },
                onMoveDeck: {
                    isShowingMoreOptions = false
                    deckToMove = deck
                },
                onManageCards: {
                    isShowingMoreOptions = false

                    deckToManageCards = isParentDeck
                        ? selectedChapter
                        : deck

                    isShowingEditCards = true
                },
                onResetProgress: {
                    isShowingMoreOptions = false
                    deckToReset = nil
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
            deckToReset != nil
                ? "Reset Chapter Progress?"
                : "Reset Deck Progress?",
            isPresented: $isShowingResetConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                deckToReset = nil
            }

            Button("Reset", role: .destructive) {
                resetProgress()
                deckToReset = nil
            }
        } message: {
            if let deckToReset {
                Text(
                    "This will reset all learning progress for \"\(deckToReset.title)\". Its flashcards will not be deleted."
                )
            } else if isParentDeck {
                Text(
                    "This will reset the learning progress of all \(childDecks.count) chapters and their flashcards. Your flashcards will not be deleted."
                )
            } else {
                Text(
                    "This will reset all learning progress for \"\(deck.title)\". Your flashcards will not be deleted."
                )
            }
        }

        .alert(
            deckToDelete != nil
                ? "Delete Chapter?"
                : "Delete Deck?",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                deckToDelete = nil
            }

            Button("Delete", role: .destructive) {
                deleteDeck()
                deckToDelete = nil
            }
        } message: {
            if let deckToDelete {
                Text(
                    "\"\(deckToDelete.title)\" and its \(deckToDelete.cards.count) flashcards will be deleted."
                )
            } else if isParentDeck {
                Text(
                    "\"\(deck.title)\" contains \(childDecks.count) chapters and \(allChildCards.count) flashcards. All of them will be deleted."
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

        .navigationDestination(isPresented: $isShowingEditChapter) {
            if let selectedChapter {
                CreateOwnDeckView(
                    existingDeck: selectedChapter
                )
            }
        }

        .navigationDestination(isPresented: $isShowingEditCards) {
        if let deckToManageCards {
            AddFlashcardView(
                deck: deckToManageCards,
                isEditMode: true
            )
        }
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
        .navigationDestination(isPresented: $isShowingExam) {
            if let examQuestionsResponse {
                ExamTakingView(
                    questionsResponse: examQuestionsResponse,
                    onFinished: {
                        Task {
                            await loadExamProgression()
                        }
                    }
                )
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else {
                return
            }

            startGenerationPollingIfNeeded()
            await loadExamProgressionIfNeeded()
        }
        .onDisappear {
            stopGenerationPolling()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomStudyBar
        }
    }

    private var chapterSelector: some View {
        Button {
            isShowingChapterPicker = true
        } label: {
            HStack(spacing: 12) {

                // Chapter number / fallback icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appAccent.opacity(0.10))

                    if let position = selectedChapter?.position {
                        Text("\(position + 1)")
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 13
                                )
                            )
                            .foregroundStyle(Color.appAccent)
                    } else {
                        Image(systemName: "rectangle.stack.fill")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(Color.appAccent)
                    }
                }
                .frame(width: 38, height: 38)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    if let chapter = selectedChapter {
                        Text(chapter.title)
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 15
                                )
                            )
                            .foregroundStyle(
                                Color.appTextPrimary
                            )
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let position = chapter.position {
                                Text("Chapter \(position + 1)")

                                Text("•")
                            }

                            Text(
                                "\(chapter.totalCardCount) card\(chapter.totalCardCount == 1 ? "" : "s")"
                            )
                        }
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 12
                            )
                        )
                        .foregroundStyle(
                            Color.appTextSecondary
                        )

                    } else {
                        Text("Select a chapter")
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 15
                                )
                            )
                            .foregroundStyle(
                                Color.appTextPrimary
                            )

                        Text("Choose what you want to study")
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

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.appTextSecondary
                    )
            }
            .padding(.horizontal, 12)
            .frame(height: 62)
            .frame(maxWidth: .infinity)
            .background(
                Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8
                )
                .stroke(
                    Color.appBorder,
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var primaryStudyButton: some View {
        NavigationLink {
            StudyFlashcardsView(
                deck: displayedDeck
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        displayedDeck.isStudySessionActive
                            ? "Continue studying"
                            : "Start studying"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )

                    Text(
                        "\(availableCards.count) card\(availableCards.count == 1 ? "" : "s")"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 11
                        )
                    )
                    .opacity(0.70)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(
                Color.appAccent,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(availableCards.isEmpty)
        .opacity(
            availableCards.isEmpty
                ? 0.45
                : 1
        )
    }

    private var deckIdentitySection: some View {
        VStack(alignment: .leading, spacing: 16) {

            // MARK: Title

            VStack(alignment: .leading, spacing: 6) {
                Text(displayedDeck.title)
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 24
                        )
                    )
                    .foregroundStyle(Color.appTextPrimary)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                if let parentTitle = displayedDeckParentTitle {
                    HStack(spacing: 7) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(
                                .system(
                                    size: 11,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(Color.appAccent)

                        Text(parentTitle)
                            .font(
                                .custom(
                                    "PlusJakartaSans-Medium",
                                    size: 13
                                )
                            )
                            .foregroundStyle(
                                Color.appTextSecondary
                            )
                            .lineLimit(1)
                    }
                } else if !displayedDeck.subject.isEmpty {
                    Text(displayedDeck.subject)
                        .font(
                            .custom(
                                "PlusJakartaSans-Medium",
                                size: 13
                            )
                        )
                        .foregroundStyle(
                            Color.appTextSecondary
                        )
                }
            }

            // MARK: Quick Info

            HStack(spacing: 0) {
                deckStat(
                    value: "\(displayedDeck.totalCardCount)",
                    label: "Cards"
                )

                statDivider

                deckStat(
                    value: "\(masteredCards)",
                    label: "Mastered"
                )

                statDivider

                deckStat(
                    value: "\(Int(masteryProgress * 100))%",
                    label: "Progress"
                )
            }
            .padding(.vertical, 14)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        Color.appBorder,
                        lineWidth: 1
                    )
            }
        }
    }

    private func deckStat(
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 16
                    )
                )
                .foregroundStyle(
                    Color.appTextPrimary
                )

            Text(label)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 11
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.appBorder)
            .frame(
                width: 1,
                height: 30
            )
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

    private var isFailedGeneration: Bool {
        deck.parentDeck == nil && deck.generationStatus == "failed"
    }

    private var retryPlan: DeckPlanResponse {
        DeckPlanResponse(
            title: deck.title,
            subject: deck.subject,
            educationLevel: deck.educationLevel,
            learningLanguage: deck.learningLanguage ?? "English",
            chapters: childDecks.map { childDeck in
                ChapterPlan(
                    title: childDeck.title,
                    description: "",
                    keyConcepts: [],
                    cardCount: childDeck.totalCardCount
                )
            }
        )
    }

    private var retryGenerationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GENERATION FAILED")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(Color.appError)

            Text("Mr. Ed can try generating the unfinished chapters again.")
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)

            if let retryErrorMessage {
                Text(retryErrorMessage)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color.appError)
            }

            Button {
                retryGeneration()
            } label: {
                HStack(spacing: 10) {
                    if isRetryingGeneration {
                        ProgressView()
                            .tint(Color.appTextPrimary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }

                    Text(isRetryingGeneration ? "Retrying..." : "Retry generation")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))

                    Spacer()
                }
                .foregroundStyle(Color.appTextPrimary)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isRetryingGeneration)
            .opacity(isRetryingGeneration ? 0.6 : 1)
        }
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private func retryGeneration() {
        guard !isRetryingGeneration else {
            return
        }

        isRetryingGeneration = true
        retryErrorMessage = nil

        Task { @MainActor in
            do {
                try await AIService.shared.retryDeck(
                    deckID: deck.id,
                    plan: retryPlan
                )

                deck.generationStatus = "generating"
                for childDeck in childDecks {
                    if childDeck.generationStatus != "completed" {
                        childDeck.generationStatus = "generating"
                    }
                }

                isRetryingGeneration = false
                startGenerationPollingIfNeeded()

            } catch {
                retryErrorMessage = error.localizedDescription
                isRetryingGeneration = false
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

        if let deckToDelete {
            // Delete only the selected chapter.
            decksToDelete = [deckToDelete]
        } else if isParentDeck {
            // Delete the parent deck and all of its chapters.
            decksToDelete = [deck] + childDecks
        } else {
            // Delete the standalone deck.
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

        if let deckToReset {
            // Reset only the selected chapter.
            decksToReset = [deckToReset]
        } else if isParentDeck {
            // Reset every chapter under the parent deck.
            decksToReset = childDecks
        } else {
            // Reset the standalone deck.
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
            targetDeck.studyAllBatchCardIDs = []
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
        .padding(.horizontal, 20)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .padding(.horizontal, 20)
    }

    private func masteredCount(for deck: StudyDeck) -> Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.correctCount > 0
        }.count
    }

    private var examSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXAMS")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 11
                    )
                )
                .foregroundStyle(Color.appTextSecondary)

            if isDeckGenerationInProgress {
                Label(
                    "Cards are still generating. Exams will be available when they're ready.",
                    systemImage: "hourglass"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 13
                    )
                )
                .foregroundStyle(Color.appWarning)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.appSurface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                }
            }

            if isLoadingExams && examProgression == nil {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.appAccent)

                    Text("Loading exam status...")
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 13
                            )
                        )
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
            } else if let examErrorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(examErrorMessage)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 13
                            )
                        )
                        .foregroundStyle(Color.appError)

                    Button("Try again") {
                        Task {
                            await loadExamProgression()
                        }
                    }
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 13
                        )
                    )
                    .foregroundStyle(Color.appAccent)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.appSurface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                }
            } else if let exams = examProgression?.exams.filter(\.applicable), !exams.isEmpty {
                ForEach(exams) { exam in
                    examStatusCard(exam)
                }
            } else {
                Text("No exams are available for this deck yet.")
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

    private func examStatusCard(
        _ exam: ExamStatusResponse
    ) -> some View {
        let isAvailable = exam.applicable && exam.available &&
            !isDeckGenerationInProgress
        let isThisExamGenerating = isGeneratingExam &&
            generatingExamType == exam.examType
        let statusColor = exam.passed
            ? Color.appSuccess
            : isAvailable
                ? Color.appAccent
                : Color.appTextSecondary

        return Button {
            generateExam(exam)
        } label: {
            HStack(spacing: 14) {
            Image(systemName: examIcon(for: exam.examType))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 40, height: 40)
                .background(
                    Color.appSecondarySurface,
                    in: RoundedRectangle(cornerRadius: 8)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(examTitle(for: exam.examType))
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )
                    .foregroundStyle(Color.appTextPrimary)

                Text(
                    isDeckGenerationInProgress
                        ? "Waiting for cards"
                        : examStatusLabel(exam)
                )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 12
                        )
                    )
                    .foregroundStyle(statusColor)
            }

            Spacer()

            if isThisExamGenerating {
                ProgressView()
                    .tint(Color.appAccent)
            } else if let bestScore = exam.bestScore {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(bestScore)%")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 16
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Best")
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 10
                            )
                        )
                        .foregroundStyle(Color.appTextSecondary)
                }
            } else if exam.attemptCount > 0 {
                Text("\(exam.attemptCount) attempt\(exam.attemptCount == 1 ? "" : "s")")
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 11
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)
            }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .disabled(!isAvailable || isGeneratingExam)
        .opacity(isAvailable ? 1 : 0.65)
        .accessibilityLabel(
            "\(examTitle(for: exam.examType)), \(examAccessibilityStatus(exam))"
        )
    }

    private func examAccessibilityStatus(
        _ exam: ExamStatusResponse
    ) -> String {
        if isDeckGenerationInProgress {
            return "Waiting for cards to finish generating"
        }

        return examStatusLabel(exam)
    }

    private func examTitle(for type: ExamType) -> String {
        switch type {
        case .firstHalf:
            return "First Half Exam"
        case .secondHalf:
            return "Second Half Exam"
        case .final:
            return "Final Exam"
        }
    }

    private func examIcon(for type: ExamType) -> String {
        switch type {
        case .firstHalf:
            return "1.circle"
        case .secondHalf:
            return "2.circle"
        case .final:
            return "flag.checkered"
        }
    }

    private func examStatusLabel(
        _ exam: ExamStatusResponse
    ) -> String {
        if !exam.applicable {
            return "Not applicable"
        }

        if exam.completed {
            return exam.passed ? "Passed" : "Not passed"
        }

        return exam.available ? "Available" : "Locked"
    }

    private func loadExamProgressionIfNeeded() async {
        guard isParentDeck, examProgression == nil else {
            return
        }

        await loadExamProgression()
    }

    private func loadExamProgression() async {
        guard !isLoadingExams else {
            return
        }

        isLoadingExams = true
        examErrorMessage = nil

        do {
            let progression = try await ExamAPI.shared.getExams(
                parentDeckID: deck.id
            )

            examProgression = progression
            isLoadingExams = false

        } catch {
            examErrorMessage = error.localizedDescription
            isLoadingExams = false
        }
    }

    private func generateExam(_ exam: ExamStatusResponse) {
        guard exam.applicable, exam.available,
              !isDeckGenerationInProgress,
              !isGeneratingExam else {
            return
        }

        isGeneratingExam = true
        generatingExamType = exam.examType
        examErrorMessage = nil

        Task { @MainActor in
            do {
                let response = try await ExamAPI.shared.generateExam(
                    parentDeckID: deck.id,
                    examType: exam.examType
                )

                guard !response.questions.isEmpty else {
                    throw ExamFeatureError.emptyQuestions
                }

                examQuestionsResponse = response
                isGeneratingExam = false
                generatingExamType = nil
                isShowingExam = true

            } catch {
                examErrorMessage = error.localizedDescription
                isGeneratingExam = false
                generatingExamType = nil
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
            .padding(.vertical, 20)
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

    private var studyAllButton: some View {
        NavigationLink {
            StudyFlashcardsView(
                decks: childDecks
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack.fill")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        hasStudyAllProgress
                            ? "Continue Study All"
                            : "Study All"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )

                    Text(
                        "\(allChildCards.count) cards across \(childDecks.count) chapters"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 11
                        )
                    )
                    .opacity(0.70)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
            }
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(
                Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8
                )
                .stroke(
                    Color.appBorder,
                    lineWidth: 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(allChildCards.isEmpty)
        .opacity(
            allChildCards.isEmpty
                ? 0.45
                : 1
        )
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

    private var bottomStudyBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {

                Group {
                    if selectedStudyScope == .chapter {
                        primaryStudyButton
                    } else {
                        studyAllButton
                    }
                }

                if isParentDeck {
                    Menu {
                        Button {
                            selectedStudyScope = .chapter
                        } label: {
                            Label(
                                "Chapter",
                                systemImage:
                                    selectedStudyScope == .chapter
                                    ? "checkmark"
                                    : "rectangle.stack"
                            )
                        }

                        Button {
                            selectedStudyScope = .all
                        } label: {
                            Label(
                                "All",
                                systemImage:
                                    selectedStudyScope == .all
                                    ? "checkmark"
                                    : "square.stack.3d.up"
                            )
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(
                                systemName:
                                    selectedStudyScope == .chapter
                                    ? "rectangle.stack"
                                    : "square.stack.3d.up"
                            )
                            .font(.system(size: 16, weight: .semibold))

                            Text(
                                selectedStudyScope == .chapter
                                    ? "Chapter"
                                    : "All"
                            )
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 10
                                )
                            )
                        }
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(width: 72, height: 52)
                        .background(
                            Color.appSurface,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    Color.appBorder,
                                    lineWidth: 1
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
        }
    }

    private var contentSectionToggle: some View {
        HStack(spacing: 4) {
            contentSectionButton(
                title: "Cards",
                icon: "rectangle.stack",
                section: .cards
            )

            contentSectionButton(
                title: "Exams",
                icon: "doc.text",
                section: .exams
            )
        }
        .padding(4)
        .background(
            Color.appSecondarySurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.appBorder,
                    lineWidth: 1
                )
        }
    }

    private func contentSectionButton(
        title: String,
        icon: String,
        section: ContentSection
    ) -> some View {
        let isSelected = selectedContentSection == section

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedContentSection = section
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 13
                        )
                    )
            }
            .foregroundStyle(
                isSelected
                    ? Color.appTextPrimary
                    : Color.appTextSecondary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                isSelected
                    ? Color.appSurface
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {

                
                Text("CARDS")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 11
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                Button {
                    deckToManageCards = isParentDeck
                        ? selectedChapter
                        : deck

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
        LazyVStack(spacing: 12) {

            ForEach(
                Array(
                    availableCards.enumerated()
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
