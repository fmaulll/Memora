import SwiftUI

struct AIDeckSetupView: View {

    @Environment(\.dismiss) private var dismiss

    let onDeckCreated: (StudyDeck) -> Void
    let parentDeck: StudyDeck?

    @State private var topic = ""
    @State private var educationLevel = "University"
    @State private var studyGoal = ""
    @State private var cardCount = 20

    @State private var isGenerating = false
    @State private var generatedPlan: DeckPlanResponse?
    @State private var isShowingPlanPreview = false
    @State private var errorMessage: String?

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
        "Professional"
    ]

    var body: some View {

        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    header

                    topicSection

                    educationSection

                    goalSection

                    cardCountSection

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
                    onDeckCreated: onDeckCreated,
                    parentDeck: parentDeck
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

            Picker(
                "Education Level",
                selection: $educationLevel
            ) {
                ForEach(educationLevels, id: \.self) { level in
                    Text(level)
                        .tag(level)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 56)
            .padding(.horizontal, 16)
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

    // MARK: - Card Count

    private var cardCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("NUMBER OF CARDS")

                Spacer()

                Text("\(cardCount)")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 16
                        )
                    )
                    .foregroundStyle(accent)
            }

            Slider(
                value: Binding(
                    get: {
                        Double(cardCount)
                    },
                    set: {
                        cardCount = Int($0)
                    }
                ),
                in: 10...50,
                step: 5
            )
            .tint(accent)

            HStack {
                Text("10")
                Spacer()
                Text("50")
            }
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 11
                )
            )
            .foregroundStyle(.white.opacity(0.35))
        }
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
                    studyGoal: studyGoal.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    cardCount: cardCount
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
