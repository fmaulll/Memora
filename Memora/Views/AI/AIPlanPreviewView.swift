import SwiftUI

struct AIPlanPreviewView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plan: DeckPlanResponse
    let studyPurpose: String
    let targetDate: Date?
    let intensity: StudyIntensity
    let timezone: String

    let onDeckCreated: (StudyDeck) -> Void
    let existingDeck: StudyDeck?
    var requiresSubscription: Bool = false

    @State private var showingSubscriptionPaywall = false
    @State private var isGenerating = false
    @State private var generatedDeck: GeneratedDeckResponse?
    @State private var preparedDeck: StudyDeck?
    @State private var generatedTimeline: StudyTimelineResponse?
    @State private var isShowingDeckPreview = false
    @State private var errorMessage: String?
    @State private var previewTimeline: StudyTimelineResponse?
    @State private var previewIntensity: StudyIntensity

    init(plan: DeckPlanResponse, studyPurpose: String, targetDate: Date?, intensity: StudyIntensity, timezone: String,
         onDeckCreated: @escaping (StudyDeck) -> Void, existingDeck: StudyDeck?, requiresSubscription: Bool = false) {
        self.plan = plan
        self.studyPurpose = studyPurpose
        self.targetDate = targetDate
        self.intensity = intensity
        self.timezone = timezone
        self.onDeckCreated = onDeckCreated
        self.existingDeck = existingDeck
        self.requiresSubscription = requiresSubscription
        _previewIntensity = State(initialValue: intensity)
        _previewTimeline = State(initialValue: plan.timeline)
    }

    private let accent = Color.appAccent

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

                    timelinePreview

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
                                Color.appError
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
                    generateButton
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(
                    .black.opacity(0.92)
                )
            }
        }
        .subscriptionPaywall(isPresented: $showingSubscriptionPaywall)
        .navigationBarBackButtonHidden()
        .preferredColorScheme(.dark)
        .task {
            if previewTimeline == nil { await refreshPreview() }
        }
        .navigationDestination(
            isPresented: $isShowingDeckPreview
        ) {
            if let generatedDeck {
                AIDeckPreviewView(
                    deck: generatedDeck,
                    timeline: generatedTimeline,
                    targetDate: targetDate,
                    onDeckCreated: onDeckCreated,
                    existingDeck: existingDeck,
                    requiresSubscription: requiresSubscription,
                    preparedDeck: preparedDeck
                )
            }
        }
        
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("AI STUDY PLAN")
                .font(.custom("PlusJakartaSans-Bold", size: 11, relativeTo: .caption))
                .tracking(1.5)
                .foregroundStyle(Color.appAccent)

            Text(plan.title)
                .font(.custom("PlusJakartaSans-ExtraBold", size: 30, relativeTo: .largeTitle))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(
                "Review the learning structure before generating your flashcards."
            )
                .font(.custom("PlusJakartaSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appTextSecondary)
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

    private var timelinePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STUDY TIMELINE").font(.custom("PlusJakartaSans-Bold", size: 11)).tracking(1).foregroundStyle(Color.appTextSecondary)
            Picker("Daily pace", selection: $previewIntensity) {
                ForEach(StudyIntensity.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: previewIntensity) { _, _ in Task { await refreshPreview() } }
            if let timeline = previewTimeline {
                Text(timeline.targetDate.map { "Goal: \($0)" } ?? "Estimated finish: \(timeline.estimatedFinishDate ?? "Calculating")")
                    .font(.custom("PlusJakartaSans-Bold", size: 17)).foregroundStyle(Color.appTextPrimary)
                Text("\(timeline.totalDays) days · \(timeline.dailyMinutesBudget ?? 0) minutes per day")
                    .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
                if timeline.isOverloaded == true {
                    Label("This pace cannot fit the full plan before the deadline.", systemImage: "exclamationmark.triangle.fill")
                        .font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(Color.appWarning)
                }
            } else {
                ProgressView("Forecasting your schedule…").tint(Color.appAccent)
            }
        }
        .padding(16).background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
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
            foreground: Color.appTextPrimary
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

        if let generatedDeck {
            finishGeneration(generatedDeck)
            return
        }

        isGenerating = true
        errorMessage = nil

        Task {
            do {

                let response =
                    try await AIService.shared.generateDeck(
                        plan: plan,
                        studyPurpose: studyPurpose,
                        targetDate: targetDate,
                        requiresSubscription: requiresSubscription,
                        intensity: previewIntensity,
                        timezone: timezone
                    )

                await MainActor.run {
                    generatedDeck = response.deck
                    generatedTimeline = response.timeline

                    isGenerating = false

                    finishGeneration(response.deck)
                }

            } catch {

                await MainActor.run {
                    showingSubscriptionPaywall = (error as? APIError)?.requiresSubscription == true
                    errorMessage = error.localizedDescription

                    isGenerating = false
                }
            }
        }
    }

    private func refreshPreview() async {
        do {
            let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .iso8601)
            formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
            let request = GenerateDeckRequest(plan: plan, studyPurpose: studyPurpose,
                                              targetDate: targetDate.map { formatter.string(from: $0) },
                                              intensity: previewIntensity, timezone: timezone)
            previewTimeline = try await AIService.shared.previewTimeline(request: request)
        } catch { errorMessage = error.localizedDescription }
    }

    private func finishGeneration(_ generatedDeck: GeneratedDeckResponse) {
        do {
            // Save the gated first deck before the timeline preview so leaving
            // this screen or relaunching cannot lose its subscription gate.
            if requiresSubscription && preparedDeck == nil {
                preparedDeck = try AIDeckCreationService.shared.createDeck(
                    from: generatedDeck,
                    existingDeck: existingDeck,
                    modelContext: modelContext,
                    requiresSubscription: true
                )
            }

            if targetDate != nil {
                isShowingDeckPreview = true
            } else if let preparedDeck {
                onDeckCreated(preparedDeck)
            } else {
                createDeck(generatedDeck)
            }
        } catch {
            showingSubscriptionPaywall = (error as? APIError)?.requiresSubscription == true
            errorMessage = error.localizedDescription
        }
    }

    private func createDeck(_ generatedDeck: GeneratedDeckResponse) {
        do {
            let createdDeck = try AIDeckCreationService.shared.createDeck(
                from: generatedDeck,
                existingDeck: existingDeck,
                modelContext: modelContext,
                requiresSubscription: requiresSubscription
            )

            onDeckCreated(createdDeck)

        } catch {
            showingSubscriptionPaywall = (error as? APIError)?.requiresSubscription == true
            errorMessage = error.localizedDescription
        }
    }
}
