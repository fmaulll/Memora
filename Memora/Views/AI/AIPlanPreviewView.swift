import SwiftUI

struct AIPlanPreviewView: View {

    @Environment(\.dismiss) private var dismiss

    let plan: DeckPlanResponse
    let onDeckCreated: (StudyDeck) -> Void
    let parentDeck: StudyDeck?

    @State private var isGenerating = false
    @State private var generatedDeck: GeneratedDeckResponse?
    @State private var isShowingDeckPreview = false
    @State private var errorMessage: String?

    private let accent = Color(
        red: 0.40,
        green: 0.40,
        blue: 0.95
    )

    private var totalCards: Int {
        plan.chapters.reduce(0) {
            $0 + $1.cardCount
        }
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    header

                    summary

                    chapters

                    if let errorMessage {
                        Text(errorMessage)
                            .font(
                                .custom(
                                    "PlusJakartaSans-Regular",
                                    size: 13
                                )
                            )
                            .foregroundStyle(
                                .red.opacity(0.9)
                            )
                    }
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
                        currentStep: 2,
                        accent: accent
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    generateButton
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(
                    .black.opacity(0.92)
                )
            }
        }
        .navigationBarBackButtonHidden()
        .preferredColorScheme(.dark)
        .navigationDestination(
            isPresented: $isShowingDeckPreview
        ) {
            if let generatedDeck {
                AIDeckPreviewView(
                    deck: generatedDeck,
                    parentDeck: parentDeck,
                    onDeckCreated: onDeckCreated
                )
            }
        }
        
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("AI STUDY PLAN")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(accent)

            Text(plan.title)
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
                "Review the learning structure before generating your flashcards."
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

    private var summary: some View {
        HStack(spacing: 12) {

            summaryItem(
                icon: "book.closed.fill",
                value: "\(plan.chapters.count)",
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

    // MARK: - Chapters

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("CHAPTERS")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 11
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.45)
                )

            ForEach(
                Array(plan.chapters.enumerated()),
                id: \.element.id
            ) { index, chapter in

                chapterRow(
                    number: index + 1,
                    chapter: chapter
                )
            }
        }
    }

    private func chapterRow(
        number: Int,
        chapter: ChapterPlan
    ) -> some View {

        HStack(spacing: 14) {

            Text(
                String(
                    format: "%02d",
                    number
                )
            )
            .font(
                .custom(
                    "PlusJakartaSans-Bold",
                    size: 12
                )
            )
            .foregroundStyle(accent)
            .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(chapter.title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 14
                        )
                    )
                    .foregroundStyle(.white)

                Text(
                    "\(chapter.cardCount) flashcards"
                )
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
        .padding(16)
        .background(
            .white.opacity(0.06),
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        AppButton(
            title: isGenerating
                ? "Generating..."
                : "Continue",
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
            generateCards()
        }
        .disabled(isGenerating)
        .padding(.horizontal, 20)
        .ignoresSafeArea(
            .keyboard,
            edges: .bottom
        )
    }

    // MARK: - Generate Cards

    private func generateCards() {

        guard !isGenerating else {
            return
        }

        isGenerating = true
        errorMessage = nil

        Task {
            do {

                let deck =
                    try await AIService.shared.generateDeck(
                        from: plan
                    )

                await MainActor.run {
                    generatedDeck = deck
                    isGenerating = false
                    isShowingDeckPreview = true
                }

            } catch {

                await MainActor.run {
                    errorMessage =
                        error.localizedDescription

                    isGenerating = false
                }
            }
        }
    }
}