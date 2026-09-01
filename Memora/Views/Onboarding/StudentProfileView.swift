import SwiftUI

struct StudentProfileView: View {

    let onFinish: (
        String,
        String,
        String
    ) -> Void

    private enum Step {
        case name
        case education
        case school
        case studyReason
        case finished
        case reasonReaction
    }

    @State private var step: Step = .name

    @State private var name = ""
    @State private var selectedEducation = ""
    @State private var selectedReason = ""

    @State private var displayedText = ""
    @State private var isTyping = true

    private let educationOptions = [
        "High School",
        "University",
        "Working",
        "Self-taught",
        "Something else"
    ]

    private let studyReasons = [
        "Pass an exam",
        "Get certified",
        "Advance my career",
        "Learn something new",
        "I have no choice"
    ]

    private var reasonReaction: String {

        switch selectedReason {

        case "Pass an exam":
            return "Then we'd better not waste time."

        case "Get certified":
            return "Good. Something measurable."

        case "Advance my career":
            return "Finally. A practical reason."

        case "Learn something new":
            return "Curiosity isn't a bad habit."

        case "I have no choice":
            return "At least you're honest."

        default:
            return "Interesting."
        }
    }

    var body: some View {

        ZStack {

            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                Image(step == .reasonReaction ? "MrEdThinking" : "MrEdJudging")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 260)

                Spacer()
                    .frame(height: 28)

                Text(displayedText)
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 24
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )
                    .multilineTextAlignment(.center)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 80
                    )
                    .padding(.horizontal, 28)

                Spacer()
                    .frame(height: 24)

                inputSection

                Spacer()
            }
        }
        .task {
            await startCurrentStep()
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {

        switch step {

        case .name:

            VStack(spacing: 14) {

                TextField(
                    "Your name",
                    text: $name
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 16
                    )
                )
                .padding()
                .background(
                    Color.white.opacity(0.07),
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .disabled(isTyping)

                AppButton(
                    title: "Tell him",
                    icon: .sf("arrow.right"),
                    iconPosition: .right,
                    foreground: .black,
                    background: Color.appAccent
                ) {
                    nextStep()
                }
                .disabled(
                    name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty || isTyping
                )
                .opacity(
                    name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty || isTyping
                    ? 0.45
                    : 1
                )
                .padding(.horizontal, 24)
            }

        case .education:

            VStack(spacing: 10) {

                ForEach(
                    educationOptions,
                    id: \.self
                ) { option in

                    Button {

                        selectedEducation = option

                    } label: {

                        HStack {

                            Text(option)
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 15
                                    )
                                )

                            Spacer()

                            if selectedEducation == option {

                                Image(
                                    systemName: "checkmark.circle.fill"
                                )
                            }
                        }
                        .foregroundStyle(
                            selectedEducation == option
                                ? Color.appAccent
                                : Color.appTextPrimary
                        )
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            selectedEducation == option
                                ? Color.appAccent.opacity(0.12)
                                : Color.white.opacity(0.07),
                            in: RoundedRectangle(
                                cornerRadius: 14
                            )
                        )
                        .overlay {

                            RoundedRectangle(
                                cornerRadius: 14
                            )
                            .stroke(
                                selectedEducation == option
                                    ? Color.appAccent
                                    : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTyping)
                }

                AppButton(
                    title: "Continue",
                    icon: .sf("arrow.right"),
                    iconPosition: .right,
                    foreground: .black,
                    background: Color.appAccent
                ) {

                    nextStep()

                }
                .disabled(
                    selectedEducation.isEmpty || isTyping
                )
                .opacity(
                    selectedEducation.isEmpty || isTyping
                        ? 0.45
                        : 1
                )
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)

        case .school:

            EmptyView()

        case .studyReason:

            VStack(spacing: 10) {

                ForEach(
                    studyReasons,
                    id: \.self
                ) { reason in

                    Button {

                        selectedReason = reason

                    } label: {

                        HStack {

                            Text(reason)
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 15
                                    )
                                )

                            Spacer()

                            if selectedReason == reason {

                                Image(
                                    systemName: "checkmark.circle.fill"
                                )
                            }
                        }
                        .foregroundStyle(
                            selectedReason == reason
                                ? Color.appAccent
                                : Color.appTextPrimary
                        )
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            selectedReason == reason
                                ? Color.appAccent.opacity(0.12)
                                : Color.white.opacity(0.07),
                            in: RoundedRectangle(
                                cornerRadius: 14
                            )
                        )
                        .overlay {

                            RoundedRectangle(
                                cornerRadius: 14
                            )
                            .stroke(
                                selectedReason == reason
                                    ? Color.appAccent
                                    : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTyping)
                }

                AppButton(
                    title: "Continue",
                    icon: .sf("arrow.right"),
                    iconPosition: .right,
                    foreground: .black,
                    background: Color.appAccent
                ) {

                    nextStep()

                }
                .disabled(
                    selectedReason.isEmpty || isTyping
                )
                .opacity(
                    selectedReason.isEmpty || isTyping
                        ? 0.45
                        : 1
                )
                .padding(.top, 12)
            }
            .padding(.horizontal, 24)

        case .reasonReaction:

            EmptyView()

        case .finished:

            AppButton(
                title: "Show me what you've got.",
                icon: .sf("arrow.right"),
                iconPosition: .right,
                foreground: .black,
                background: Color.appAccent
            ) {
                onFinish(
                    name,
                    selectedEducation,
                    selectedReason
                )
            }
            .disabled(isTyping)
            .opacity(isTyping ? 0.45 : 1)
            .padding(.horizontal, 24)
        }
    }


    // MARK: - Flow

    private func nextStep() {

        switch step {

        case .name:
            step = .education

        case .education:
            step = .school

        case .school:
            step = .studyReason

        case .studyReason:
            step = .reasonReaction

        case .reasonReaction:
            step = .finished

        case .finished:
            break
        }

        Task {
            await startCurrentStep()
        }
    }


    // MARK: - Dialogue

    private func startCurrentStep() async {

        isTyping = true
        displayedText = ""

        switch step {

        case .name:

            await type(
                "First things first. What's your name?"
            )

        case .education:

            await type(
                "Alright, \(name). What are you doing these days?"
            )

        case .school:

            await type(
                "Where do you go to school?"
            )

            try? await Task.sleep(
                nanoseconds: 1_200_000_000
            )

            displayedText = ""

            await type(
                "Actually..."
            )

            try? await Task.sleep(
                nanoseconds: 500_000_000
            )

            displayedText = ""

            await type(
                "I don't care where you go to school."
            )

            try? await Task.sleep(
                nanoseconds: 900_000_000
            )

            displayedText = ""

            await type(
                "A school doesn't study for you."
            )

            try? await Task.sleep(
                nanoseconds: 1_400_000_000
            )

            nextStep()

            return

        case .studyReason:

            await type(
                "So why are you here?"
            )

        case .reasonReaction:

            let reaction = reasonReaction

            await type(reaction)

            try? await Task.sleep(
                nanoseconds: 1_500_000_000
            )

            nextStep()

            return

        case .finished:

            await type(
                "Alright. I know enough about you."
            )

            try? await Task.sleep(
                nanoseconds: 1_000_000_000
            )

            displayedText = ""

            await type(
                "Now let's see what you're actually trying to learn."
            )
        }

        isTyping = false
    }


    // MARK: - Typing Effect

    private func type(
        _ text: String
    ) async {

        displayedText = ""

        for character in text {

            guard !Task.isCancelled else {
                return
            }

            displayedText.append(character)

            let delay: UInt64

            switch character {

            case ".", "!", "?":
                delay = 180_000_000

            case ",":
                delay = 80_000_000

            case " ":
                delay = 15_000_000

            default:
                delay = 35_000_000
            }

            try? await Task.sleep(
                nanoseconds: delay
            )
        }
    }
}


#Preview {

    StudentProfileView {
        name,
        education,
        reason in

        print(name)
        print(education)
        print(reason)
    }
}