import SwiftUI

struct StudyFlashcardsView: View {
    let deck: StudyDeck

    @Environment(\.dismiss) private var dismiss

    @State private var currentCardIndex = 0
    @State private var isAnswerRevealed = false
    @State private var isSessionComplete = false

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let subjectColor = Color(red: 0.13, green: 0.77, blue: 0.37)

    private var currentCard: StudyFlashcardCard? {
        guard deck.cards.indices.contains(currentCardIndex) else {
            return nil
        }

        return deck.cards[currentCardIndex]
    }

    private var progress: Double {
        guard !deck.cards.isEmpty else {
            return 0
        }

        return Double(currentCardIndex + 1) / Double(deck.cards.count)
    }

    var body: some View {
        AppBackground {
            VStack(spacing: 0) {

                // MARK: Top Bar

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(width: 40, height: 40)
                            .background(
                                .white.opacity(0.10),
                                in: Circle()
                            )
                    }
                    .accessibilityLabel("Close study session")

                    Spacer()

                    Text("\(min(currentCardIndex + 1, deck.cards.count)) / \(deck.cards.count)")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // MARK: Progress

                StudyProgressBar(
                    progress: progress,
                    accent: accent
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if deck.cards.isEmpty {
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

    // MARK: Study Content

    private func studyContent(card: StudyFlashcardCard) -> some View {
        VStack(spacing: 0) {

            Spacer(minLength: 30)

            // MARK: Flashcard

            Button {
                revealAnswer()
            } label: {
                FlashcardView(
                    card: card,
                    subject: deck.subject,
                    isAnswerRevealed: isAnswerRevealed,
                    subjectColor: subjectColor
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)

            Spacer(minLength: 20)

            // MARK: Bottom Content

            if isAnswerRevealed {
                RatingControls(
                    onRate: { rating in
                        rateCard(rating)
                    }
                )
                .padding(.horizontal, 20)
                .transition(
                    .opacity
                    .combined(with: .move(edge: .bottom))
                )
            } else {
                RevealHint()
                    .transition(.opacity)
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
        withAnimation(.easeInOut(duration: 0.25)) {
            if currentCardIndex >= deck.cards.count - 1 {
                isSessionComplete = true
            } else {
                currentCardIndex += 1
                isAnswerRevealed = false
            }
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
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)

                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Study Session Complete")
                .font(.custom("PlusJakartaSans-ExtraBold", size: 26))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("You reviewed \(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s").")
                .font(.custom("PlusJakartaSans-Regular", size: 16))
                .foregroundStyle(.white.opacity(0.55))

            AppButton(
                title: "Done",
                icon: .sf("checkmark"),
                iconPosition: .right,
                background: LinearGradient(
                    colors: [
                        accent,
                        Color(red: 0.55, green: 0.36, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ) {
                dismiss()
            }
            .padding(.horizontal, 20)

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
        VStack(spacing: 0) {

            // Subject

            Text(subject.uppercased())
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .tracking(0.5)
                .foregroundStyle(subjectColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    subjectColor.opacity(0.12),
                    in: Capsule()
                )

            Spacer(minLength: 28)

            // Question

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

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: isAnswerRevealed ? 330 : 265)
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

            Text("How well did you know this?")
                .font(.custom("PlusJakartaSans-Regular", size: 12))
                .foregroundStyle(.white.opacity(0.35))

            HStack(spacing: 10) {
                RatingButton(
                    title: "Again",
                    icon: "arrow.counterclockwise",
                    color: .red
                ) {
                    onRate(.again)
                }

                RatingButton(
                    title: "Hard",
                    icon: "exclamationmark",
                    color: .orange
                ) {
                    onRate(.hard)
                }

                RatingButton(
                    title: "Good",
                    icon: "checkmark",
                    color: .green
                ) {
                    onRate(.good)
                }

                RatingButton(
                    title: "Easy",
                    icon: "bolt.fill",
                    color: .blue
                ) {
                    onRate(.easy)
                }
            }
        }
    }
}

// MARK: - Rating Button

private struct RatingButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 11))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                color.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        color.opacity(0.25),
                        lineWidth: 1
                    )
            }
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
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(accent)
                    .frame(
                        width: geometry.size.width * progress
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

// MARK: - Rating

private enum CardRating {
    case again
    case hard
    case good
    case easy
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