import SwiftUI
import SwiftData

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

@MainActor
struct StudyFlashcardsView: View {
    private let source: StudySessionSource

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var study: StudySession
    @State private var isAnswerRevealed = false
    @State private var saveErrorMessage: String?
    @State private var failedRating: CardRating?

    private var currentCard: StudyFlashcardCard? { study.currentCard }
    private var completedCardCount: Int { study.completedCount }
    private var currentBatchCardIDs: Set<UUID> { study.batchIDs }
    private var isSessionComplete: Bool { study.isComplete }

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let subjectColor = Color(red: 0.13, green: 0.77, blue: 0.37)

    init(deck: StudyDeck) {
        source = StudySessionSource(deck: deck)
        _study = State(initialValue: StudySession(decks: [deck], combined: false))
    }

    init(decks: [StudyDeck]) {
        source = StudySessionSource(decks: decks)
        _study = State(initialValue: StudySession(decks: decks, combined: true))
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

    private var isCurrentCardReview: Bool { study.isCurrentCardReview }

    private var studyPhaseTitle: String {
        isCurrentCardReview
            ? "REVIEW"
            : "NEW"
    }

    private var currentBatchNumber: Int {
        let completedBatches =
            completedCardCount / StudySession.batchSize

        return completedBatches + 1
    }

    private var totalBatchCount: Int {
        guard !source.cards.isEmpty else {
            return 0
        }

        return Int(
            ceil(
                Double(source.cards.count) /
                Double(StudySession.batchSize)
            )
        )
    }

    private var currentBatchSize: Int {
        currentBatchCardIDs.count
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {

                // MARK: Top Bar

                HStack {
                    Button {
                        closeSession()
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
        .task {
            let revision = LocalAccountStore.shared.revision
            await StudyProgressSync.shared.prepare(study, context: modelContext)
            guard !Task.isCancelled, LocalAccountStore.shared.revision == revision else { return }
            startSession()
        }
        .alert("Could not save study progress", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("Try Again") {
                if let failedRating {
                    rateCard(failedRating, presentationID: study.presentationID)
                } else if !study.isStarted {
                    startSession()
                } else {
                    closeSession()
                }
            }
            Button("Stay here", role: .cancel) { }
        } message: {
            Text(saveErrorMessage ?? "Your answer was not saved. Please try again.")
        }
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
        let presentationID = study.presentationID
        return VStack(spacing: 0) {

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

            if isAnswerRevealed && study.isStarted {
                RatingControls(
                    onRate: { rating in
                        rateCard(rating, presentationID: presentationID)
                    }
                )
                .disabled(!study.isStarted || failedRating != nil)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .transition(
                    .opacity
                    .combined(with: .move(edge: .bottom))
                )
            }

            if let failedRating {
                Button("Retry saving answer") {
                    rateCard(failedRating, presentationID: study.presentationID)
                }
                .padding(.top, 12)
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

    // MARK: Local persistence

    private func startSession() {
        do {
            try study.start(context: modelContext)
        } catch {
            saveErrorMessage = (error as? StudyResetError)?.localizedDescription ?? "Your session could not be saved. Please try again."
        }
    }

    private func rateCard(_ rating: CardRating, presentationID: UUID) {
        guard isAnswerRevealed else { return }
        do {
            if try study.rate(rating, expectedPresentation: presentationID) {
                failedRating = nil
                isAnswerRevealed = false
                if study.reachedFlushBoundary { flushProgress() }
            }
        } catch {
            if failedRating == nil { failedRating = rating }
            saveErrorMessage = (error as? StudyResetError)?.localizedDescription ?? "Your answer was not saved. It is still on this card. Please try again."
        }
    }

    private func flushProgress() {
        // Independent task: dismissing the view must not cancel a persisted upload.
        Task { await StudyProgressSync.shared.flush(context: modelContext) }
    }

    private func closeSession() {
        do {
            // Start/save errors must not silently dismiss an unpersisted session.
            if !study.isStarted { try study.start(context: modelContext) }
            try study.saveForExit()
            flushProgress()
            dismiss()
        } catch is StudyResetError {
            // Reset owns persisted state; closing this old screen must not write it.
            dismiss()
        } catch {
            saveErrorMessage = "Your session could not be saved. Please try again."
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
                closeSession()
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
