import SwiftUI

struct AIDeckSetupView: View {

    @Environment(\.dismiss) private var dismiss

    let onDeckCreated: (StudyDeck) -> Void
    let existingDeck: StudyDeck?

    @State private var topic = ""
    @State private var educationLevel = "University"
    @State private var studyPurpose = "Learn from Scratch"
    @State private var studyGoal = ""
    @State private var learningDepth = "Comprehensive"

    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    // @State private var cardCount = 20

    @State private var isGenerating = false
    @State private var generatedPlan: DeckPlanResponse?
    @State private var isShowingPlanPreview = false
    @State private var errorMessage: String?

    private let learningDepthOptions = [
        "Quick Review",
        "Balanced",
        "Comprehensive",
    ]

    private let accent = Color(
        red: 0.40,
        green: 0.40,
        blue: 0.95
    )

    private let educationLevels = [
        "Elementary School",
        "Middle School",
        "High School",
        "University",
        "Professional",
        "Self-taught",
    ]

    private let studyPurposeOptions = [
        "Learn from Scratch",
        "Expand My Knowledge",
        "Prepare for an Exam",
        "Prepare for a Certification"
    ]

    var body: some View {

        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    header

                    topicSection

                    educationSection

                    studyPurposeSection

                    goalSection

                    learningDepthSection

                    if requiresTargetDate {
                        targetDateSection
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(
                                .custom(
                                    "PlusJakartaSans-Regular",
                                    size: 13
                                )
                            )
                            .foregroundStyle(.red.opacity(0.9))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationDestination(
            isPresented: $isShowingPlanPreview
        ) {
            if let generatedPlan {
                AIPlanPreviewView(
                    plan: generatedPlan,
                    studyPurpose: studyPurpose,
                    targetDate: hasTargetDate ? targetDate : nil,
                    onDeckCreated: onDeckCreated,
                    existingDeck: existingDeck
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {

                WorkflowIndicator(
                    numberOfSteps: 4,
                    currentStep: 1,
                    accent: accent
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                generateButton
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.black.opacity(0.92))
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BackNavigationBar {
                EmptyView()
            }
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREATE WITH AI")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(accent)

            Text("What do you want\nto learn?")
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
                "Tell Memora what you want to learn and AI will build a study plan for you."
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 14
                )
            )
            .foregroundStyle(.white.opacity(0.55))
            .lineSpacing(4)
        }
    }

    // MARK: - Topic

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TOPIC")

            TextField(
                "e.g. Python programming from scratch",
                text: $topic
            )
            .textInputAutocapitalization(.sentences)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        .white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
    }

    // MARK: - Education

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("EDUCATION LEVEL")

            Menu {
                ForEach(educationLevels, id: \.self) { level in
                    Button {
                        educationLevel = level
                    } label: {
                        Text(level)
                    }
                }
            } label: {
                HStack {
                    Text(educationLevel)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            .white.opacity(0.10),
                            lineWidth: 1
                        )
                }
            }
        }
    }

    // MARK: - Study Goal

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("STUDY GOAL")

            TextField(
                "e.g. Learn Python fundamentals",
                text: $studyGoal
            )
            .textInputAutocapitalization(.sentences)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        .white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
    }

    // MARK: - Learning Depth

    private var learningDepthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("LEARNING DEPTH")

            VStack(spacing: 10) {
                learningDepthOption(
                    title: "Quick Review",
                    description: "Essential concepts only"
                )

                learningDepthOption(
                    title: "Standard",
                    description: "Solid coverage for normal learning"
                )

                learningDepthOption(
                    title: "Comprehensive",
                    description: "Thorough coverage of important concepts"
                )
            }
        }
    }

    private func learningDepthOption(
        title: String,
        description: String
    ) -> some View {
        Button {
            learningDepth = title
        } label: {
            HStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Text(description)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 12
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.45)
                        )
                }

                Spacer()

                Image(
                    systemName:
                        learningDepth == title
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 20))
                .foregroundStyle(
                    learningDepth == title
                    ? accent
                    : .white.opacity(0.25)
                )
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .background(
                learningDepth == title
                ? accent.opacity(0.12)
                : .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        learningDepth == title
                        ? accent.opacity(0.5)
                        : .white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate

    private var generateButton: some View {
        AppButton(
            title: isGenerating
                ? "Generating..."
                : "Continue",
            foreground: canContinue
                ? .white
                : .white.opacity(0.45),
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
            generatePlan()
        }
        .disabled(!canContinue || isGenerating)
        .padding(.horizontal, 20)
        .ignoresSafeArea(
            .keyboard,
            edges: .bottom
        )
    }

    // MARK: - Study Purpose

    private var studyPurposeSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionTitle("STUDY PURPOSE")

            VStack(spacing: 10) {

                studyPurposeOption(
                    title: "Learn from Scratch",
                    description: "Build a strong foundation from the beginning",
                    icon: "book.closed"
                )

                studyPurposeOption(
                    title: "Expand My Knowledge",
                    description: "Deepen your understanding of a subject",
                    icon: "brain.head.profile"
                )

                studyPurposeOption(
                    title: "Prepare for an Exam",
                    description: "Study toward an upcoming academic exam",
                    icon: "graduationcap"
                )

                studyPurposeOption(
                    title: "Prepare for a Certification",
                    description: "Prepare for a professional certification",
                    icon: "checkmark.seal"
                )
            }
        }
    }

    private func studyPurposeOption(
        title: String,
        description: String,
        icon: String
    ) -> some View {

        Button {
            studyPurpose = title

            if !requiresTargetDate {
                hasTargetDate = false
            }

        } label: {

            HStack(spacing: 14) {

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        studyPurpose == title
                        ? accent
                        : .white.opacity(0.55)
                    )
                    .frame(width: 24)

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(title)
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Text(description)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 12
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.45)
                        )
                }

                Spacer()

                Image(
                    systemName:
                        studyPurpose == title
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 20))
                .foregroundStyle(
                    studyPurpose == title
                    ? accent
                    : .white.opacity(0.25)
                )
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 70)
            .background(
                studyPurpose == title
                ? accent.opacity(0.12)
                : .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        studyPurpose == title
                        ? accent.opacity(0.5)
                        : .white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Target Date

    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionTitle("TARGET DATE")

            Toggle(
                isOn: $hasTargetDate
            ) {
                VStack(alignment: .leading, spacing: 4) {

                    Text("I have a target date")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "We'll create a study timeline based on your deadline."
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 12
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )
                }
            }
            .tint(accent)
            .padding(16)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )

            if hasTargetDate {

                DatePicker(
                    "Target Date",
                    selection: $targetDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(accent)
                .padding(16)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(
                .custom(
                    "PlusJakartaSans-Bold",
                    size: 11
                )
            )
            .foregroundStyle(.white.opacity(0.45))
    }

    private func generatePlan() {
        guard !isGenerating else { return }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let plan = try await AIService.shared.generatePlan(
                    topic: topic.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    educationLevel: educationLevel,
                    studyPurpose: studyPurpose,
                    studyGoal: studyGoal.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    learningDepth: learningDepth,
                    targetDate: hasTargetDate ? targetDate : nil
                )

                await MainActor.run {
                    generatedPlan = plan
                    isGenerating = false
                    isShowingPlanPreview = true
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private var requiresTargetDate: Bool {
        studyPurpose == "Prepare for an Exam"
        ||
        studyPurpose == "Prepare for a Certification"
    }

    private var canContinue: Bool {
        !topic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        &&
        !studyGoal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
