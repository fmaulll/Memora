import SwiftUI

struct StudyFlashcardsView: View {
    private let decks: [StudyDeck]
    private let isCombined: Bool
    private let cards: [StudyFlashcardCard]
    private let title: String
    private let subject: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var queue: StudySessionQueue
    @State private var isAnswerRevealed = false
    @State private var saveError: String?
    @State private var cardShownAt = Date()

    private let spacedRepetitionService = SpacedRepetitionService()

    init(deck: StudyDeck) {
        self.init(decks: [deck], isCombined: false)
    }

    init(decks: [StudyDeck]) {
        self.init(decks: decks, isCombined: true)
    }

    private init(decks: [StudyDeck], isCombined: Bool) {
        self.decks = decks
        self.isCombined = isCombined
        title = isCombined ? (decks.first?.parentDeck?.title ?? "Study All") : (decks.first?.title ?? "Study")
        subject = decks.first?.subject ?? ""
        var seen = Set<UUID>()
        let cards = decks.flatMap(\.cards).filter { !$0.needsDeletion && seen.insert($0.id).inserted }
        self.cards = cards

        let isResuming = decks.contains { isCombined ? $0.isStudyAllSessionActive : $0.isStudySessionActive }
        let ids = isResuming ? decks.flatMap {
            // Include the old learning queue so existing sessions remain resumable.
            isCombined
                ? $0.studyAllQueueIDs + $0.studyAllLearningQueueIDs
                : $0.studyQueueIDs + $0.learningQueueIDs
        }.filter { seen.contains($0) } : cards.map(\.id)
        let confirmations = isResuming ? decks.flatMap {
            isCombined ? $0.studyAllConfirmationIDs : $0.studyConfirmationIDs
        } : []
        _queue = State(initialValue: StudySessionQueue(cardIDs: ids, confirmationIDs: Set(confirmations)))
    }

    private var currentCard: StudyFlashcardCard? {
        guard let id = queue.cardIDs.first else { return nil }
        return cards.first { $0.id == id }
    }

    private var progress: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(cards.count - queue.cardIDs.count) / Double(cards.count)
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {
                header
                ProgressView(value: progress)
                    .tint(Color.appAccent)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                if let saveError {
                    Text(saveError)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundStyle(Color.appError)
                        .padding(.horizontal, 20)
                }

                if cards.isEmpty {
                    completionContent(isEmpty: true)
                } else if queue.cardIDs.isEmpty {
                    completionContent(isEmpty: false)
                } else if let card = currentCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(queue.confirmationIDs.contains(card.id)
                                 ? "One more time. Recall it without looking."
                                 : "Recall the answer, then reveal it to check.")
                                .font(.custom("PlusJakartaSans-Regular", size: 14))
                                .foregroundStyle(Color.appTextSecondary)

                            flashcard(card)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        studyControls(cardID: card.id)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
        .preferredColorScheme(.dark)
        .onAppear {
            saveSession()
            retryPendingReviews()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveSession() }
        }
    }

    private var header: some View {
        HStack {
            Button {
                if saveSession() { dismiss() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("Save and close study session")
            Spacer()
            Text("\(queue.cardIDs.count) remaining")
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func flashcard(_ card: StudyFlashcardCard) -> some View {
        Button {
            isAnswerRevealed = true
        } label: {
            VStack(spacing: 24) {
                if !subject.isEmpty {
                    Text(subject.uppercased())
                        .font(.custom("PlusJakartaSans-Bold", size: 11))
                        .foregroundStyle(Color.appAccent)
                }
                Text(card.front)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 22))
                    .foregroundStyle(Color.appTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                cardImage(card.frontImageData)

                if isAnswerRevealed {
                    Rectangle().fill(Color.appBorder).frame(height: 1)
                    Text("ANSWER")
                        .font(.custom("PlusJakartaSans-Bold", size: 11))
                        .foregroundStyle(Color.appTextSecondary)
                    Text(card.back)
                        .font(.custom("PlusJakartaSans-Regular", size: 18))
                        .foregroundStyle(Color.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    cardImage(card.backImageData)
                }
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 280)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityHint(isAnswerRevealed ? "Rate your recall using the buttons below." : "Tap to reveal the answer.")
    }

    @ViewBuilder
    private func cardImage(_ data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func studyControls(cardID: UUID) -> some View {
        VStack(spacing: 12) {
            Text(isAnswerRevealed ? "Could you recall it before looking?" : "Think first. No points for guessing.")
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)

            if isAnswerRevealed {
                HStack(spacing: 12) {
                    ratingButton("Again", detail: "Try again soon", icon: "arrow.counterclockwise", isPositive: false) {
                        rateCard(.again, cardID: cardID)
                    }
                    ratingButton("Got it", detail: queue.confirmationIDs.contains(cardID) ? "Finish this card" : "Check once more", icon: "checkmark", isPositive: true) {
                        rateCard(.good, cardID: cardID)
                    }
                }
            } else {
                AppButton(title: "Reveal answer", foreground: Color.appBackground, background: Color.appAccent) {
                    isAnswerRevealed = true
                }
            }
        }
        .padding(20)
        .background(Color.appBackground)
        .overlay(alignment: .top) { Rectangle().fill(Color.appBorder).frame(height: 1) }
    }

    private func ratingButton(_ title: String, detail: String, icon: String, isPositive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.custom("PlusJakartaSans-Bold", size: 16))
                Text(detail)
                    .font(.custom("PlusJakartaSans-Regular", size: 11))
            }
            .foregroundStyle(isPositive ? Color.appBackground : Color.appTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isPositive ? Color.appAccent : Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(isPositive ? Color.appAccent : Color.appBorder, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func rateCard(_ rating: CardRating, cardID: UUID) {
        guard isAnswerRevealed, let card = currentCard, card.id == cardID else { return }
        let confirmed = queue.rate(rating)
        spacedRepetitionService.review(card: card, rating: rating, isConfirmed: confirmed)
        isAnswerRevealed = false
        saveSession()
        cardShownAt = .now

        // A first "Got it" introduces the card to the backend. The immediate
        // local confirmation is a UX check, not a second spaced-repetition event.
        guard rating == .again || !confirmed else { return }
        recordReview(card: card, rating: rating)
    }

    private func recordReview(card: StudyFlashcardCard, rating: CardRating) {
        let pending = StudyReviewEventStore.shared.pending(for: card.id)
        let event = pending ?? StudyReviewRequest(
            eventID: UUID(), cardID: card.id, rating: rating.rawValue,
            occurredAt: .now,
            elapsedMS: max(0, Int(Date().timeIntervalSince(cardShownAt) * 1_000)),
            expectedRevision: card.studyStateRevision
        )
        do { try StudyReviewEventStore.shared.save(event) }
        catch { saveError = "Progress saved locally, but the review is waiting to sync."; return }
        Task { @MainActor in
            do {
                let receipt = try await AIService.shared.recordReview(event)
                guard receipt.cardID == card.id else { return }
                card.studyStateRevision = receipt.stateRevision
                card.nextReviewAt = receipt.nextDueAt
                StudyReviewEventStore.shared.clear(cardID: card.id)
                try? modelContext.save()
            } catch {
                // Keep the exact event for retry; never make a new UUID to
                // bypass a conflict or duplicate-delivery condition.
                saveError = "Progress saved locally. This review will sync when the connection is back."
            }
        }
    }

    private func retryPendingReviews() {
        for card in cards {
            guard let request = StudyReviewEventStore.shared.pending(for: card.id) else { continue }
            Task { @MainActor in
                do {
                    let receipt = try await AIService.shared.recordReview(request)
                    guard receipt.cardID == card.id else { return }
                    card.studyStateRevision = receipt.stateRevision
                    card.nextReviewAt = receipt.nextDueAt
                    StudyReviewEventStore.shared.clear(cardID: card.id)
                    try? modelContext.save()
                } catch { /* Preserve the exact idempotent body for next launch. */ }
            }
        }
    }

    @discardableResult
    private func saveSession() -> Bool {
        for deck in decks {
            let cardIDs = Set(deck.cards.filter { !$0.needsDeletion }.map(\.id))
            let remaining = queue.cardIDs.filter { cardIDs.contains($0) }
            let confirmations = queue.confirmationIDs.intersection(cardIDs)
            let completed = max(0, cardIDs.count - remaining.count)
            let isActive = !queue.cardIDs.isEmpty
            if isCombined {
                deck.studyAllQueueIDs = remaining
                deck.studyAllLearningQueueIDs = []
                deck.studyAllConfirmationIDs = Array(confirmations)
                deck.studyAllCompletedCount = isActive ? completed : 0
                // Keep completed chapters part of a resumable combined session.
                deck.isStudyAllSessionActive = isActive
            } else {
                deck.studyQueueIDs = remaining
                deck.learningQueueIDs = []
                deck.studyConfirmationIDs = Array(confirmations)
                deck.studyCompletedCount = isActive ? completed : 0
                deck.isStudySessionActive = isActive
            }
        }
        do {
            try modelContext.save()
            saveError = nil
            return true
        } catch {
            saveError = "Progress couldn't be saved. Try closing the session again."
            return false
        }
    }

    private func completionContent(isEmpty: Bool) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: isEmpty ? "rectangle.on.rectangle.slash" : "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(isEmpty ? Color.appTextSecondary : Color.appSuccess)
            Text(isEmpty ? "No flashcards yet" : "Session complete")
                .font(.custom("PlusJakartaSans-Bold", size: 26))
                .foregroundStyle(Color.appTextPrimary)
            Text(isEmpty ? "Add some cards to start studying." : "Every remaining card passed its recall check. Come back for your next review.")
                .font(.custom("PlusJakartaSans-Regular", size: 15))
                .foregroundStyle(Color.appTextSecondary)
            AppButton(title: "Done", foreground: Color.appBackground, background: Color.appAccent) {
                if saveSession() { dismiss() }
            }
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(20)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        StudyFlashcardsView(deck: StudyDeck(
            title: "Cell Division", subject: "Biology", educationLevel: "University",
            cards: [StudyFlashcardCard(front: "What is mitosis?", back: "Cell division producing two genetically identical daughter cells.")]
        ))
    }
}
