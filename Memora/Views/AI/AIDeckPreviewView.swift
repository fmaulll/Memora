import SwiftUI

struct AIDeckPreviewView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let deck: GeneratedDeckResponse
    let onDeckCreated: (StudyDeck) -> Void
    let existingDeck: StudyDeck?

    @State private var isCreating = false

    private let accent = Color(
        red: 0.40,
        green: 0.40,
        blue: 0.95
    )

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    header

                    summary

                    cards

                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BackNavigationBar {
                    EmptyView()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {

                    WorkflowIndicator(
                        numberOfSteps: 4,
                        currentStep: 3,
                        accent: accent
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    createButton
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(
                    .black.opacity(0.92)
                )
            }
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("AI FLASHCARDS")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(accent)

            Text(deck.title)
                .font(
                    .custom(
                        "PlusJakartaSans-ExtraBold",
                        size: 38
                    )
                )
                .foregroundStyle(.white)
                .tracking(-1)
                .lineSpacing(-3)

            Text(
                "Review your generated flashcards before creating the deck."
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 14
                )
            )
            .foregroundStyle(
                .white.opacity(0.55)
            )
            .lineSpacing(4)
        }
    }

    // MARK: - Summary

    private var totalCards: Int {
        deck.chapters.reduce(0) {
            $0 + $1.cards.count
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {

            summaryItem(
                icon: "book.closed.fill",
                value: "\(deck.chapters.count)",
                title: "Chapters"
            )

            summaryItem(
                icon: "rectangle.stack.fill",
                value: "\(totalCards)",
                title: "Cards"
            )
        }
    }

    private func summaryItem(
        icon: String,
        value: String,
        title: String
    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {

                Text(value)
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 18
                        )
                    )
                    .foregroundStyle(.white)

                Text(title)
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 11
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.4)
                    )
            }

            Spacer()
        }
        .padding(14)
        .background(
            .white.opacity(0.06),
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
    }

    // MARK: - Cards

    private var cards: some View {
        VStack(alignment: .leading, spacing: 20) {

            ForEach(deck.chapters) { chapter in

                VStack(alignment: .leading, spacing: 12) {

                    Text(chapter.title)
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 16
                            )
                        )
                        .foregroundStyle(.white)

                    ForEach(chapter.cards) { card in
                        cardRow(card)
                    }
                }
            }
        }
    }

    private func cardRow(
        _ card: GeneratedCard
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("QUESTION")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 9
                    )
                )
                .foregroundStyle(accent)

            Text(card.front)
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 14
                    )
                )
                .foregroundStyle(.white)

            Divider()
                .overlay(
                    .white.opacity(0.08)
                )

            Text("ANSWER")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 9
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.4)
                )

            Text(card.back)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 14
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.65)
                )
        }
        .padding(16)
        .background(
            .white.opacity(0.06),
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
    }

    // MARK: - Create Button

    private var createButton: some View {
        AppButton(
            title: isCreating
                ? "Creating..."
                : "Create Deck",
            foreground: .white,
            background: AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accent,
                        Color(
                            red: 0.55,
                            green: 0.36,
                            blue: 0.96
                        )
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        ) {
            guard !isCreating else { return }

            isCreating = true

            if let createdDeck = createDeck() {
                onDeckCreated(createdDeck)
            } else {
                isCreating = false
            }
        }
        .disabled(isCreating)
        .padding(.horizontal, 20)
    }

    // MARK: - Create

    private func createDeck() -> StudyDeck? {
        let rootDeck: StudyDeck

        if let existingDeck {
            guard existingDeck.parentDeck == nil else {
                print("❌ AI DECK MUST BE ROOT")
                return nil
            }

            guard existingDeck.cards.isEmpty else {
                print("❌ AI DECK MUST BE EMPTY")
                return nil
            }

            rootDeck = existingDeck
            rootDeck.isSynced = false

        } else {
            rootDeck = StudyDeck(
                title: deck.title,
                subject: deck.subject,
                educationLevel: deck.educationLevel
            )

            rootDeck.isSynced = false
            modelContext.insert(rootDeck)
        }

        for chapter in deck.chapters {
            let chapterDeck = StudyDeck(
                title: chapter.title,
                subject: deck.subject,
                educationLevel: deck.educationLevel,
                parentDeck: rootDeck
            )

            modelContext.insert(chapterDeck)

            for generatedCard in chapter.cards {
                let card = StudyFlashcardCard(
                    front: generatedCard.front,
                    back: generatedCard.back,
                    deck: chapterDeck
                )

                card.isSynced = false
                card.syncState = 1

                modelContext.insert(card)
            }
        }

        do {
            try modelContext.save()

            print("========== AI DECK CREATED LOCALLY ==========")
            print("ROOT DECK:", rootDeck.title)
            print("CHAPTERS:", rootDeck.childDecks.count)

            for chapter in rootDeck.childDecks {
                print(
                    "CHAPTER:",
                    chapter.title,
                    "| CARDS:",
                    chapter.cards.count
                )
            }

            return rootDeck

        } catch {
            print(
                "❌ FAILED TO CREATE AI DECK:",
                error
            )

            return nil
        }
    }
}