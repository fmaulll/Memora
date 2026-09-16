import SwiftUI

//  StudyFlashcardsView.swift
//  Memora
//  Created by fuckdazeshit on 14/08/26.

// StudyFlashcardsView is the main view for studying flashcards in a deck. It manages the study session state, including the current card, progress, and user ratings. It also handles the transition between the initial queue of cards and the learning queue for spaced repetition.

private struct StudySessionSource {
    enum Kind {
        case single
        case combined
    }

    let kind: Kind
    let title: String
    let subject: String
    let cards: [StudyFlashcardCard]
    let decks: [StudyDeck]

    init(deck: StudyDeck) {
        self.kind = .single
        self.title = deck.title
        self.subject = deck.subject
        self.cards = deck.cards.filter {
            !$0.needsDeletion
        }
        self.decks = [deck]
    }

    init(decks: [StudyDeck]) {
        self.kind = .combined

        self.title = decks.first?.parentDeck?.title
            ?? decks.first?.title
            ?? "Study Session"

        self.subject = decks.first?.subject ?? ""

        self.cards = decks
            .flatMap(\.cards)
            .filter {
                !$0.needsDeletion
            }

        self.decks = decks
    }

    var isCombined: Bool {
        kind == .combined
    }
}

struct StudyFlashcardsView: View {
    private let source: StudySessionSource

    private var deck: StudyDeck? {
        source.decks.count == 1 ? source.decks.first : nil
    }

    private var isCombinedSession: Bool {
        source.kind == .combined
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: Study Session Queues
    //
    // `sessionCards` is the initial, one-pass-through queue for this session.
    // Cards leave it permanently once rated — either into `learningCards`
    // (Again/Hard) or straight to completion (Good/Easy).
    //
    // `learningCards` is the "learning boundary" queue. Once `sessionCards`
    // is empty, Memora cycles ONLY through `learningCards` until every card
    // in it has been rated Good or Easy. A card can never re-enter
    // `learningCards` once it has left via Good/Easy.
    @State private var sessionCards: [StudyFlashcardCard]
    @State private var learningCards: [StudyFlashcardCard] = []

    @State private var currentBatchCardIDs: Set<UUID> = []
    @State private var lastPresentedCardID: UUID?
    
    @State private var isAnswerRevealed = false
    @State private var isSessionComplete = false
    @State private var completedCardCount = 0

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let subjectColor = Color(red: 0.13, green: 0.77, blue: 0.37)

    private let spacedRepetitionService = SpacedRepetitionService()

    // How many other learning-queue cards a requeued card is reinserted behind.
    // Again resurfaces sooner than Hard, mirroring Anki's short learning steps.
    private static let againRequeueDelay = 1
    private static let hardRequeueDelay = 2
    private static let studyBatchSize = 4

    init(deck: StudyDeck) {
        let source = StudySessionSource(deck: deck)

        self.source = source

        let cardsByID = Dictionary(
            uniqueKeysWithValues: source.cards.map {
                ($0.id, $0)
            }
        )

        if deck.isStudySessionActive {

            let restoredSessionCards =
                deck.studyQueueIDs.compactMap {
                    cardsByID[$0]
                }

            let restoredLearningCards =
                deck.learningQueueIDs.compactMap {
                    cardsByID[$0]
                }

            _sessionCards = State(
                initialValue: restoredSessionCards
            )

            _learningCards = State(
                initialValue: restoredLearningCards
            )

            _completedCardCount = State(
                initialValue: deck.studyCompletedCount
            )

            // For now, rebuild the active batch from the
            // cards at the front of the restored queues.
            let activeCards =
                restoredLearningCards.isEmpty
                    ? Array(
                        restoredSessionCards.prefix(
                            Self.studyBatchSize
                        )
                    )
                    : restoredLearningCards

            let restoredBatchIDs: Set<UUID>

            if !deck.studyBatchCardIDs.isEmpty {
                restoredBatchIDs = Set(
                    deck.studyBatchCardIDs
                )
            } else {
                restoredBatchIDs = Set(
                    activeCards.map(\.id)
                )
            }

            _currentBatchCardIDs = State(
                initialValue: restoredBatchIDs
            )

        } else {
            _sessionCards = State(
                initialValue: source.cards
            )

            _learningCards = State(
                initialValue: []
            )

            _completedCardCount = State(
                initialValue: 0
            )

            _currentBatchCardIDs = State(
                initialValue: Self.makeBatchIDs(
                    from: source.cards
                )
            )
        }
    }
    
    init(decks: [StudyDeck]) {

        let source = StudySessionSource(decks: decks)

        self.source = source

        print("========== STUDY ALL DEBUG ==========")
        print("DECK COUNT:", decks.count)
        print("SOURCE CARD COUNT:", source.cards.count)

        for deck in decks {
            print(
                "DECK:",
                deck.title,
                "| CARDS:",
                deck.cards.count
            )
        }

        print("=====================================")

        let cardsByID = Dictionary(
            uniqueKeysWithValues: source.cards.map {
                ($0.id, $0)
            }
        )

        let hasActiveStudyAllSession = decks.contains {
            $0.isStudyAllSessionActive
        }

        print(
            "HAS ACTIVE STUDY ALL SESSION:",
            hasActiveStudyAllSession
        )

        for deck in decks where deck.isStudyAllSessionActive {
            print(
                "ACTIVE:",
                deck.title,
                "| QUEUE:",
                deck.studyAllQueueIDs.count,
                "| LEARNING:",
                deck.studyAllLearningQueueIDs.count,
                "| COMPLETED:",
                deck.studyAllCompletedCount
            )
        }

        if hasActiveStudyAllSession {

            let queue = decks.flatMap { deck in
                deck.studyAllQueueIDs.compactMap {
                    cardsByID[$0]
                }
            }

            let learning = decks.flatMap { deck in
                deck.studyAllLearningQueueIDs.compactMap {
                    cardsByID[$0]
                }
            }

            _sessionCards = State(
                initialValue: queue
            )

            _learningCards = State(
                initialValue: learning
            )

            _completedCardCount = State(
                initialValue: decks.reduce(0) {
                    $0 + $1.studyAllCompletedCount
                }
            )

            let savedBatchCardIDs = Set(
                decks.flatMap {
                    $0.studyAllBatchCardIDs
                }
            )

            _currentBatchCardIDs = State(
                initialValue:
                    savedBatchCardIDs.isEmpty
                        ? Self.makeBatchIDs(from: queue)
                        : savedBatchCardIDs
            )

        } else {

            _sessionCards = State(
                initialValue: source.cards
            )

            _learningCards = State(
                initialValue: []
            )

            _completedCardCount = State(
                initialValue: 0
            )

            _currentBatchCardIDs = State(
                initialValue: Self.makeBatchIDs(
                    from: source.cards
                )
            )

            print("FRESH STUDY ALL")
            print("FRESH CARDS:", source.cards.count)
            print(
                "FRESH BATCH:",
                Self.makeBatchIDs(
                    from: source.cards
                ).count
            )
        }
    }

    // The card currently on screen: the initial queue is always shown first,
    // then the learning queue once the initial queue is exhausted.
    private var currentCard: StudyFlashcardCard? {

        // Cards in the current batch that have
        // not been seen for the first time yet.
        let newCards = sessionCards.filter {
            currentBatchCardIDs.contains($0.id)
        }

        // Always prefer new cards first.
        if let card = newCards.first(
            where: {
                $0.id != lastPresentedCardID
            }
        ) {
            return card
        }

        // Once there are no new cards left,
        // continue through the review queue.
        if let card = learningCards.first(
            where: {
                $0.id != lastPresentedCardID
            }
        ) {
            return card
        }

        // If the same card is literally the only
        // active card remaining, repeating it is unavoidable.
        return newCards.first ?? learningCards.first
    }

    private var progress: Double {
        guard !source.cards.isEmpty else {
            return 0
        }

        return Double(completedCardCount) / Double(source.cards.count)
    }

    private var currentBatchPosition: Int {
        guard let card = currentCard else {
            return 0
        }

        let batchIDs = currentBatchCardIDs

        let batchCards = source.cards.filter {
            batchIDs.contains($0.id)
        }

        guard let index = batchCards.firstIndex(
            where: { $0.id == card.id }
        ) else {
            return 0
        }

        return index + 1
    }

    private var isCurrentCardReview: Bool {
        guard let card = currentCard else {
            return false
        }

        return learningCards.contains {
            $0.id == card.id
        }
    }

    private var studyPhaseTitle: String {
        isCurrentCardReview
            ? "REVIEW"
            : "NEW"
    }

    private var currentBatchNumber: Int {
        let completedBatches =
            completedCardCount / Self.studyBatchSize

        return completedBatches + 1
    }

    private var totalBatchCount: Int {
        guard !source.cards.isEmpty else {
            return 0
        }

        return Int(
            ceil(
                Double(source.cards.count) /
                Double(Self.studyBatchSize)
            )
        )
    }

    private var currentBatchSize: Int {
        currentBatchCardIDs.count
    }

    private static func makeBatchIDs(
        from cards: [StudyFlashcardCard]
    ) -> Set<UUID> {
        Set(
            cards
                .prefix(studyBatchSize)
                .map(\.id)
        )
    }

    private var hasActiveBatchCards: Bool {
        let hasNewCardsInBatch = sessionCards.contains {
            currentBatchCardIDs.contains($0.id)
        }

        let hasLearningCardsInBatch = learningCards.contains {
            currentBatchCardIDs.contains($0.id)
        }

        return hasNewCardsInBatch || hasLearningCardsInBatch
    }

    private func loadNextBatchIfNeeded() {
        guard !hasActiveBatchCards else {
            return
        }

        guard !sessionCards.isEmpty else {
            return
        }

        currentBatchCardIDs = Self.makeBatchIDs(
            from: sessionCards
        )
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {

                // MARK: Top Bar

                HStack {
                    Button {
                        saveStudySession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(width: 40, height: 40)
                            .background(
                                .white.opacity(0.18),
                                in: Circle()
                            )
                    }
                    .accessibilityLabel("Close study session")

                    Spacer()

                    Text("\(source.cards.count - completedCardCount) remaining")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 20)
                // .padding(.top, 8)

                // MARK: Progress

                StudyProgressBar(
                    progress: progress,
                    accent: accent
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if source.cards.isEmpty {
                    emptyState
                } else if isSessionComplete {
                    sessionCompleteView
                } else if let card = currentCard {
                    studyContent(card: card)
                }

                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
    }

    private var batchContext: some View {
        HStack(spacing: 8) {

            Text(
                "BATCH \(currentBatchNumber) OF \(totalBatchCount)"
            )
            .font(
                .custom(
                    "PlusJakartaSans-SemiBold",
                    size: 11
                )
            )
            .tracking(0.8)
            .foregroundStyle(Color.appTextSecondary)

            Text("•")
                .font(.system(size: 8))
                .foregroundStyle(Color.appTextSecondary)

            Text(studyPhaseTitle)
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .tracking(0.8)
                .foregroundStyle(
                    isCurrentCardReview
                        ? Color.appAccent
                        : Color.appTextSecondary
                )

            Spacer()

            Text(
                "\(currentBatchPosition) / \(currentBatchSize)"
            )
            .font(
                .custom(
                    "PlusJakartaSans-SemiBold",
                    size: 11
                )
            )
            .monospacedDigit()
            .foregroundStyle(Color.appTextSecondary)
        }
    }

    // MARK: Study Content

    private func studyContent(card: StudyFlashcardCard) -> some View {
        VStack(spacing: 0) {

            Spacer(minLength: 24)

            // MARK: Batch Context

            batchContext
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            // MARK: Flashcard

            Button {
                revealAnswer()
            } label: {
                FlashcardView(
                    card: card,
                    subject: source.subject,
                    isAnswerRevealed: isAnswerRevealed,
                    subjectColor: subjectColor
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            // MARK: Bottom Content

            if isAnswerRevealed {
                RatingControls(
                    onRate: { rating in
                        rateCard(rating)
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .transition(
                    .opacity
                    .combined(with: .move(edge: .bottom))
                )
            }

            Spacer(minLength: 20)
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: isAnswerRevealed
        )
    }

    // MARK: Reveal

    private func revealAnswer() {
        guard !isAnswerRevealed else {
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            isAnswerRevealed = true
        }
    }

    // MARK: Rating
    private func rateCard(_ rating: CardRating) {
        guard let card = currentCard else {
            return
        }

        lastPresentedCardID = card.id

        spacedRepetitionService.review(
            card: card,
            rating: rating
        )

        if sessionCards.contains(where: { $0.id == card.id }) {
            handleInitialCardRating(
                card,
                rating
            )
        } else {
            handleLearningCardRating(
                card,
                rating
            )
        }

        isAnswerRevealed = false

        // If the current batch has been completely learned,
        // move on to the next group of new cards.
        loadNextBatchIfNeeded()

        if sessionCards.isEmpty && learningCards.isEmpty {
            finishStudySession()
        } else {
            saveStudySession()

            withAnimation(.easeInOut(duration: 0.25)) {
                advanceToNextCard()
            }
        }
    }

    /// Handles a rating for a card still in the initial, one-pass-through queue.
    /// Good/Easy leave the session for good; Again/Hard move into the learning queue.
    private func handleInitialCardRating(
        _ card: StudyFlashcardCard,
        _ rating: CardRating
    ) {
        sessionCards.removeAll {
            $0.id == card.id
        }

        switch rating {

        case .again, .hard:
            // Failed on the first encounter.
            // Put it into the review queue with a short delay.
            requeueLearningCard(
                card,
                rating: .again
            )

        case .good, .easy:
            // Even if the user got it right the first time,
            // require one later recall before completing it.
            learningCards.append(card)
        }
    }

    /// Handles a rating for a card being cycled through the learning queue.
    /// A card can only leave the learning queue permanently via Good/Easy.
    private func handleLearningCardRating(
        _ card: StudyFlashcardCard,
        _ rating: CardRating
    ) {
        learningCards.removeAll {
            $0.id == card.id
        }

        switch rating {

        case .again, .hard:
            // Still struggling.
            // Keep the card in review and show it again later.
            requeueLearningCard(
                card,
                rating: .again
            )

        case .good, .easy:
            // Successful recall during REVIEW.
            // This card is finished for this study session.
            completedCardCount += 1
        }
    }

    /// Reinserts a struggling card into the learning queue at a short delay.
    /// Again resurfaces sooner than Hard; Good/Easy never call this.
    private func requeueLearningCard(_ card: StudyFlashcardCard, rating: CardRating) {
        let requeueDelay: Int

        switch rating {
        case .again:
            requeueDelay = Self.againRequeueDelay
        case .hard:
            requeueDelay = Self.hardRequeueDelay
        case .good, .easy:
            return
        }

        let insertionIndex = min(requeueDelay, learningCards.count)
        learningCards.insert(card, at: insertionIndex)
    }

    private func saveStudySession() {
        if isCombinedSession {
            saveCombinedStudySession()
            return
        }

        guard let deck else {
            return
        }

        deck.studyQueueIDs = sessionCards.map(\.id)
        deck.learningQueueIDs = learningCards.map(\.id)
        deck.studyCompletedCount = completedCardCount
        deck.isStudySessionActive = true

        deck.studyBatchCardIDs = Array(
            currentBatchCardIDs
        )

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to save study session:", error)
        }
    }

    private func saveCombinedStudySession() {

        for childDeck in source.decks {

            let childCards = childDeck.cards.filter {
                !$0.needsDeletion
            }

            let childCardIDs = Set(
                childCards.map(\.id)
            )

            let childSessionCards = sessionCards.filter {
                childCardIDs.contains($0.id)
            }

            let childLearningCards = learningCards.filter {
                childCardIDs.contains($0.id)
            }

            let completedCount =
                childCards.count
                - childSessionCards.count
                - childLearningCards.count

            childDeck.studyAllQueueIDs =
                childSessionCards.map(\.id)

            childDeck.studyAllLearningQueueIDs =
                childLearningCards.map(\.id)

            childDeck.studyAllCompletedCount =
                max(completedCount, 0)

            childDeck.isStudyAllSessionActive =
                !childSessionCards.isEmpty ||
                !childLearningCards.isEmpty

            childDeck.studyAllBatchCardIDs = Array(
                currentBatchCardIDs.filter { cardID in
                    childDeck.cards.contains { card in
                        card.id == cardID
                    }
                }
            )
        }

        do {
            try modelContext.save()
        } catch {
            print(
                "❌ Failed to save Study All session:",
                error
            )
        }
    }

    /// The session only completes once both the initial queue and the
    /// learning queue are empty — never just because `sessionCards` ran out.
    private func advanceToNextCard() {
        if sessionCards.isEmpty && learningCards.isEmpty {
            isSessionComplete = true
        }
    }

    private func finishStudySession() {

        isSessionComplete = true

        if isCombinedSession {
            finishCombinedStudySession()
            return
        }

        guard let deck else {
            return
        }

        deck.studyQueueIDs = []
        deck.learningQueueIDs = []
        deck.studyCompletedCount = 0
        deck.isStudySessionActive = false

        deck.studyBatchCardIDs = []

        do {
            try modelContext.save()
        } catch {
            print(
                "❌ Failed to finish study session:",
                error
            )
        }
    }

    private func finishCombinedStudySession() {

        for deck in source.decks {

            deck.studyAllQueueIDs = []

            deck.studyAllLearningQueueIDs = []

            deck.studyAllCompletedCount = 0

            deck.isStudyAllSessionActive = false

            deck.studyAllBatchCardIDs = []
        }

        do {
            try modelContext.save()
        } catch {
            print(
                "❌ Failed to finish Study All session:",
                error
            )
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 42))
                .foregroundStyle(.white.opacity(0.4))

            Text("No flashcards yet")
                .font(.custom("PlusJakartaSans-Bold", size: 22))
                .foregroundStyle(.white)

            Text("Add some cards to start studying.")
                .font(.custom("PlusJakartaSans-Regular", size: 15))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()
        }
    }

    // MARK: Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 0) {

            Spacer()

            // MARK: Completion Icon

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent)
                    .frame(width: 72, height: 72)

                Image(systemName: "checkmark")
                    .font(
                        .system(
                            size: 28,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.black)
            }

            // MARK: Title

            Text("Session complete")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 24
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .padding(.top, 24)

            // MARK: Subtitle

            Text(
                "You finished \(source.cards.count) card\(source.cards.count == 1 ? "" : "s")."
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 14
                )
            )
            .foregroundStyle(Color.appTextSecondary)
            .padding(.top, 8)

            // MARK: Summary

            HStack(spacing: 0) {

                VStack(spacing: 6) {
                    Text("\(source.cards.count)")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 20
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)

                    Text("CARDS")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 10
                            )
                        )
                        .tracking(1)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.appBorder)
                    .frame(width: 1, height: 38)

                VStack(spacing: 6) {
                    Text("\(totalBatchCount)")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 20
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)

                    Text("BATCHES")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 10
                            )
                        )
                        .tracking(1)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 18)
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
            .padding(.horizontal, 20)
            .padding(.top, 28)

            // MARK: Done

            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("Done")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 15
                            )
                        )

                    Image(systemName: "arrow.right")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Color.appAccent,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()
        }
    }
}

// MARK: - Flashcard

private struct FlashcardView: View {
    let card: StudyFlashcardCard
    let subject: String
    let isAnswerRevealed: Bool
    let subjectColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Question Label

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appAccent)
                    .frame(width: 4, height: 16)

                Text("QUESTION")
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 11
                        )
                    )
                    .tracking(1.2)
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()
            }

            .padding(.bottom, 24)

            // MARK: Question

            Text(card.front)
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 23
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            if isAnswerRevealed {

                // MARK: Divider

                Rectangle()
                    .fill(Color.appBorder)
                    .frame(height: 1)
                    .padding(.vertical, 28)

                // MARK: Answer Label

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appAccent)

                    Text("ANSWER")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 11
                            )
                        )
                        .tracking(1.2)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.bottom, 16)

                // MARK: Answer

                Text(card.back)
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 17
                        )
                    )
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(5)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .transition(
                        .opacity
                        .combined(
                            with: .move(edge: .bottom)
                        )
                    )
            }

            Spacer(minLength: 32)

            // MARK: Card Footer

            HStack(spacing: 7) {
                Image(
                    systemName: isAnswerRevealed
                        ? "checkmark"
                        : "hand.tap"
                )
                .font(.system(size: 11, weight: .semibold))

                Text(
                    isAnswerRevealed
                        ? "Answer revealed"
                        : "Tap card to reveal"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Medium",
                        size: 11
                    )
                )

                Spacer()
            }
            .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(  
            minHeight: 360,
            alignment: .topLeading
        )
        .padding(24)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isAnswerRevealed
                        ? Color.appAccent.opacity(0.35)
                        : Color.appBorder,
                    lineWidth: 1
                )
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: isAnswerRevealed
        )
    }
}

// MARK: - Reveal Hint

private struct RevealHint: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(maxWidth: 28)
                .frame(height: 1)

            Text("tap to reveal")
                .font(.custom("PlusJakartaSans-Regular", size: 12))
                .foregroundStyle(.white.opacity(0.25))

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(maxWidth: 28)
                .frame(height: 1)
        }
    }
}

// MARK: - Rating Controls

private struct RatingControls: View {
    let onRate: (CardRating) -> Void

    var body: some View {
        VStack(spacing: 12) {

            Text("Did you get it?")
                .font(
                    .custom(
                        "PlusJakartaSans-Medium",
                        size: 12
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )

            HStack(spacing: 10) {

                RatingButton(
                    title: "Again",
                    icon: "arrow.counterclockwise",
                    style: .secondary
                ) {
                    onRate(.again)
                }

                RatingButton(
                    title: "Got it",
                    icon: "checkmark",
                    style: .primary
                ) {
                    onRate(.good)
                }
            }
        }
    }
}

// MARK: - Rating Button

private struct RatingButton: View {

    enum Style {
        case primary
        case secondary
    }

    let title: String
    let icon: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )

                Text(title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 14
                        )
                    )
            }
            .foregroundStyle(
                style == .primary
                    ? Color.black
                    : Color.appTextPrimary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                style == .primary
                    ? Color.appAccent
                    : Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                if style == .secondary {
                    RoundedRectangle(
                        cornerRadius: 8
                    )
                    .stroke(
                        Color.appBorder,
                        lineWidth: 1
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Progress Bar

private struct StudyProgressBar: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {

                Capsule()
                    .fill(Color.appSecondarySurface)

                Capsule()
                    .fill(Color.appAccent)
                    .frame(
                        width: geometry.size.width
                            * min(max(progress, 0), 1)
                    )
            }
        }
        .frame(height: 4)
        .animation(
            .easeInOut(duration: 0.25),
            value: progress
        )
    }
}

// MARK: - Preview

#Preview {
    let deck = StudyDeck(
        title: "Cell Division & Mitosis",
        subject: "Biology",
        educationLevel: "University"
    )

    deck.cards = [
        StudyFlashcardCard(
            front: "What is mitosis?",
            back: "Cell division producing two genetically identical daughter cells."
        ),
        StudyFlashcardCard(
            front: "What is the purpose of mitosis?",
            back: "Mitosis is used for growth, tissue repair, and cell replacement."
        ),
        StudyFlashcardCard(
            front: "How many daughter cells are produced?",
            back: "Two genetically identical daughter cells."
        )
    ]

    return NavigationStack {
        StudyFlashcardsView(deck: deck)
    }
}
