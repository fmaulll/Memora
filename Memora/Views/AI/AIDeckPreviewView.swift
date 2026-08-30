import SwiftUI

struct AIDeckPreviewView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let deck: GeneratedDeckResponse
    let timeline: StudyTimelineResponse?

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

                    if let timeline {
                        studyTimeline(timeline)
                    }

                    chapters

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
        timeline?.totalCards ?? 0
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

    // MARK: - Study Timeline

    private func studyTimeline(
        _ timeline: StudyTimelineResponse
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text("STUDY TIMELINE")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 11
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.45)
                )

            Text(
                "\(timeline.totalDays) day study plan"
            )
            .font(
                .custom(
                    "PlusJakartaSans-Bold",
                    size: 18
                )
            )
            .foregroundStyle(.white)

            Text(
                "Complete \(timeline.totalCards) flashcards based on your study schedule."
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 13
                )
            )
            .foregroundStyle(
                .white.opacity(0.55)
            )

            VStack(spacing: 10) {

                ForEach(
                    timeline.dailyPlan,
                    id: \.day
                ) { studyDay in

                    timelineRow(studyDay)
                }
            }
        }
    }

    private func timelineRow(
        _ studyDay: StudyDayResponse
    ) -> some View {

        HStack(
            alignment: .center,
            spacing: 14
        ) {

            VStack(spacing: 2) {

                Text("DAY")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 8
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.4)
                    )

                Text("\(studyDay.day)")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 18
                        )
                    )
                    .foregroundStyle(accent)
            }
            .frame(width: 42)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(
                    studyDay.newCards > 0
                        ? "\(studyDay.newCards) new flashcards"
                        : "Review day"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 14
                    )
                )
                .foregroundStyle(.white)

                Text(studyDay.focus)
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 11
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.5)
                    )
                    .lineLimit(2)
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
                Array(deck.chapters.enumerated()),
                id: \.element.id
            ) { index, chapter in

                HStack(spacing: 14) {

                    Text("\(index + 1)")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 13
                            )
                        )
                        .foregroundStyle(accent)
                        .frame(width: 28, height: 28)
                        .background(
                            accent.opacity(0.12),
                            in: Circle()
                        )

                    Text(chapter.title)
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(
                            .white.opacity(0.4)
                        )
                }
                .padding(14)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )
            }
        }
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

            guard existingDeck.childDecks.isEmpty else {
                print("❌ AI DECK MUST HAVE NO CHILDREN")
                return nil
            }

            rootDeck = existingDeck
            rootDeck.isSynced = false

        } else {
            rootDeck = StudyDeck(
                id: deck.id,
                title: deck.title,
                subject: deck.subject,
                educationLevel: deck.educationLevel,
                generationStatus: deck.generationStatus
            )

            rootDeck.isSynced = false
            modelContext.insert(rootDeck)
        }

        for chapter in deck.chapters {

            let chapterDeck = StudyDeck(
                id: chapter.id,
                title: chapter.title,
                subject: deck.subject,
                educationLevel: deck.educationLevel,
                parentDeck: rootDeck,
                generationStatus: chapter.generationStatus
            )

            chapterDeck.isSynced = false

            modelContext.insert(chapterDeck)
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