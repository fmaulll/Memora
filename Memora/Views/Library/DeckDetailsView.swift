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

    @State private var showingSubscriptionPaywall = false
    @State private var isShowingMoveDeck = false
    @State private var isShowingCreateSubDeck = false
    @State private var isShowingEditDeck = false
    @State private var isShowingEditCards = false
    @State private var isShowingMoreOptions = false
    @State private var isShowingResetConfirmation = false
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingCreateWithAI = false

    @State private var generationPollingTask: Task<Void, Never>?
    @State private var isPollingGeneration = false
    @State private var isRetryingGeneration = false
    @State private var retryErrorMessage: String?
    @State private var showingExams = false
    @State private var examProgression: ExamProgressionResponse?
    @State private var isLoadingExams = false
    @State private var examErrorMessage: String?
    @State private var isGeneratingExam = false
    @State private var generatingExamType: ExamType?
    @State private var examQuestionsResponse: ExamQuestionsResponse?
    @State private var isShowingExam = false

    private let accent = Color.appAccent

    private var totalCards: Int {
        deck.cards.filter { !$0.needsDeletion }.count
    }

    private var studyProgress: DeckProgressSummary {
        DeckProgressSummary(deck: deck, isSubscribed: true, now: .now)
    }

    private var masteredCards: Int { studyProgress.confirmedCount }
    private var learningCards: Int { studyProgress.learningCount }

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
            .sorted(by: StudyDeck.chapterOrder)
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
        && !deck.isAIGenerated
        && !hasCards
    }

    private var canCreateWithAI: Bool {
        deck.parentDeck == nil
        && !deck.isAIGenerated
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
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if isParentDeck {
                        parentOverview
                        if !allChildCards.isEmpty {
                            NavigationLink {
                                StudyFlashcardsView(decks: childDecks)
                            } label: {
                                Label(hasStudyAllProgress ? "Continue studying chapters" : "Study all chapters", systemImage: "play.fill")
                                    .font(.custom("PlusJakartaSans-Bold", size: 15))
                                    .foregroundStyle(Color.appBackground)
                                    .frame(maxWidth: .infinity).frame(height: 54)
                                    .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        Picker("Deck section", selection: $showingExams) {
                            Text("Chapters").tag(false)
                            Text("Exams").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if showingExams { examSection } else { childDeckSection }
                    } else {
                        progressSummary
                        studyButton
                        cardsSection
                    }
                    if isFailedGeneration { retryGenerationSection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BackNavigationBar {
                    deckMoreOptionButton
                }
            }
        }
        .preferredColorScheme(.dark)
        .subscriptionPaywall(isPresented: $showingSubscriptionPaywall)
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
            startGenerationPollingIfNeeded()
            if isParentDeck { await loadExamProgression() }
        }
        .refreshable {
            if isParentDeck { await loadExamProgression() }
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
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {

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
                        ? "\(deck.educationLevel) · \(childDecks.count) chapters · \(totalStudyCards) cards"
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
                    deckID: deck.id
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
                showingSubscriptionPaywall = (error as? APIError)?.requiresSubscription == true
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
            targetDeck.studyConfirmationIDs = []
            targetDeck.studyCompletedCount = 0
            targetDeck.isStudySessionActive = false

            // Reset Study All session
            targetDeck.studyAllQueueIDs = []
            targetDeck.studyAllLearningQueueIDs = []
            targetDeck.studyAllConfirmationIDs = []
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

    private var parentOverview: some View {
        let progress = studyProgress
        return VStack(alignment: .leading, spacing: 12) {
            Text("YOUR STUDY PATH")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(Color.appTextSecondary)
            Text("\(progress.confirmedCount) of \(progress.totalCount) cards confirmed")
                .font(.custom("PlusJakartaSans-Bold", size: 18))
                .foregroundStyle(Color.appTextPrimary)
            ProgressView(value: progress.confirmedFraction).tint(Color.appAccent)
            Text("Learn the chapters, then prove it in three exams. Open Exams to see what's next.")
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }

    private var childDeckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHAPTERS · \(childDecks.count)")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(Color.appTextSecondary)
            Text("Follow the numbered chapters. Your exam requirements are shown in the Exams tab.")
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)
            ForEach(childDecks) { child in
                NavigationLink { DeckDetailsView(deck: child) } label: {
                    childDeckRow(child)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chapterExamProgress: ChapterExamProgress {
        ChapterExamProgress(chapters: childDecks)
    }

    private func canStartExam(_ type: ExamType, exams: [ExamStatusResponse]) -> Bool {
        let progress = chapterExamProgress
        return ExamAccessPolicy.canStart(type, exams: exams, isGenerating: isDeckGenerationInProgress,
                                         firstHalfComplete: progress.firstHalfComplete,
                                         secondHalfComplete: progress.secondHalfComplete)
    }

    private var examSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("EXAM MILESTONES")
                    .font(.custom("PlusJakartaSans-Bold", size: 11))
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Button { Task { await loadExamProgression() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                        .foregroundStyle(Color.appAccent)
                }
                .disabled(isLoadingExams || isGeneratingExam)
            }
            if isLoadingExams {
                ProgressView("Checking exam eligibility…")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .tint(Color.appAccent)
            }
            if let examErrorMessage {
                Text(examErrorMessage)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color.appError)
            }
            ForEach(ExamType.allCases) { type in
                examMilestone(type)
            }
        }
    }

    private func examMilestone(_ type: ExamType) -> some View {
        let exams = examProgression?.exams ?? []
        let exam = exams.first { $0.examType == type }
        let available = canStartExam(type, exams: exams)
            && !isLoadingExams && examErrorMessage == nil
        let generating = isGeneratingExam && generatingExamType == type
        let color: Color = exam?.passed == true ? .appSuccess : available ? .appAccent : .appTextSecondary
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: exam?.passed == true ? "checkmark.circle.fill" : examIcon(for: type))
                    .font(.system(size: 24)).foregroundStyle(color)
                Text(examTitle(for: type))
                    .font(.custom("PlusJakartaSans-Bold", size: 17))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                if !available && exam?.passed != true {
                    Image(systemName: "lock.fill").foregroundStyle(Color.appTextSecondary)
                }
            }
            Text(chapterExamProgress.coverage(for: type) + " · " + chapterExamProgress.completionLabel(for: type))
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundStyle(Color.appAccent)
            Text(ExamAccessPolicy.requirement(for: type))
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)
            if let exam {
                HStack {
                    Text(exam.passed ? "Passed" : available ? "Ready to take" : "Locked")
                        .foregroundStyle(color)
                    Spacer()
                    if let score = exam.bestScore { Text("Best: \(score)%") }
                    if exam.attemptCount > 0 { Text("\(exam.attemptCount) attempts") }
                }
                .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                .foregroundStyle(Color.appTextSecondary)
                if available || generating {
                    AppButton(title: generating ? "Preparing exam…" : exam.attemptCount > 0 ? "Retake exam" : "Start exam",
                              foreground: Color.appBackground, background: Color.appAccent) {
                        generateExam(exam)
                    }
                    .disabled(isGeneratingExam)
                }
            } else {
                Text(isLoadingExams ? "Checking status…" : "Availability not confirmed. Refresh to check.")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            if isDeckGenerationInProgress {
                Text("Waiting for cards to finish generating.")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(Color.appWarning)
            }
        }
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
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

    private func loadExamProgression() async {
        guard isParentDeck, !isLoadingExams else {
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
            examProgression = nil
            showingSubscriptionPaywall = (error as? APIError)?.requiresSubscription == true
            examErrorMessage = error.localizedDescription
            isLoadingExams = false
        }
    }

    private func generateExam(_ exam: ExamStatusResponse) {
        guard canStartExam(exam.examType, exams: examProgression?.exams ?? []),
              !isLoadingExams, !isGeneratingExam else {
            return
        }

        isGeneratingExam = true
        generatingExamType = exam.examType
        examErrorMessage = nil

        Task { @MainActor in
            do {
                // Recheck immediately before generation; a stale UI cannot grant access.
                let latest = try await ExamAPI.shared.getExams(parentDeckID: deck.id)
                examProgression = latest
                guard canStartExam(exam.examType, exams: latest.exams) else {
                    isGeneratingExam = false
                    generatingExamType = nil
                    return
                }
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
                showingSubscriptionPaywall = (error as? APIError)?.requiresSubscription == true
                examErrorMessage = error.localizedDescription
                isGeneratingExam = false
                generatingExamType = nil
            }
        }
    }

    private func childDeckRow(_ childDeck: StudyDeck) -> some View {
        let progress = DeckProgressSummary(deck: childDeck, isSubscribed: true, now: .now)
        return HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", (childDecks.firstIndex { $0.id == childDeck.id } ?? 0) + 1))
                .font(.custom("PlusJakartaSans-Bold", size: 16))
                .foregroundStyle(Color.appAccent)
                .frame(width: 40, height: 40)
                .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 8) {
                Text(childDeck.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundStyle(Color.appTextPrimary)
                if childDeck.generationStatus == "completed" {
                    Text("\(progress.confirmedCount)/\(progress.totalCount) cards confirmed")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundStyle(Color.appTextSecondary)
                    ProgressView(value: progress.confirmedFraction).tint(Color.appAccent)
                    if progress.hasActiveSession {
                        Text("Continue · \(progress.sessionRemaining) cards left")
                            .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                            .foregroundStyle(Color.appInfo)
                    }
                } else if childDeck.generationStatus == "failed" {
                    Text("Generation failed · open chapter")
                        .font(.custom("PlusJakartaSans-Regular", size: 12))
                        .foregroundStyle(Color.appError)
                } else {
                    generationStatusText(for: childDeck)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Color.appTextSecondary)
        }
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }

    @ViewBuilder
        private func generationStatusText(
            for childDeck: StudyDeck
        ) -> some View {

            switch childDeck.generationStatus {

            case "completed":

                Text(
                    "\(childDeck.totalCardCount) cards"
                    + (DeckProgressSummary(deck: childDeck, isSubscribed: true, now: .now).confirmedCount > 0
                        ? " · \(DeckProgressSummary(deck: childDeck, isSubscribed: true, now: .now).confirmedCount) mastered"
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
    
    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Recall progress")
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 13
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                Text("\(masteredCards) / \(totalCards) confirmed")
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
                    title: "Confirmed",
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
        .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
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
                    .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))

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

    private func flashcardRow(number: Int, card: StudyFlashcardCard) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(card.back)
                    .font(.custom("PlusJakartaSans-Regular", size: 15))
                    .foregroundStyle(Color.appTextPrimary)
                    .padding(.top, 12)
                if let data = card.backImageData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(String(format: "%02d", number))
                    .font(.custom("PlusJakartaSans-Bold", size: 13))
                    .foregroundStyle(Color.appTextSecondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.front)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                        .foregroundStyle(Color.appTextPrimary)
                    if let data = card.frontImageData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                    }
                    cardStatus(card)
                }
            }
        }
        .tint(Color.appAccent)
        .padding(16)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
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

        } else if card.interval <= 0 || card.correctCount == 0
            || (deck.isStudySessionActive && deck.studyConfirmationIDs.contains(card.id))
            || (deck.isStudyAllSessionActive && deck.studyAllConfirmationIDs.contains(card.id)) {

            Label("Learning", systemImage: "arrow.triangle.2.circlepath")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(Color.appWarning)

        } else {

            Label("Confirmed", systemImage: "checkmark.circle.fill")
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
