import SwiftUI

struct StudentProfileView: View {

    // MARK: - Callback

    let onComplete: (
        _ name: String,
        _ educationLevel: String,
        _ studyReason: String
    ) -> Void

    // MARK: - Steps

    private enum Step: Int, CaseIterable {
        case name
        case currentSituation
        case studyReason
        case intensity
        case finished
    }

    // MARK: - State

    @State private var step: Step = .name

    @State private var name = ""

    @State private var currentSituation = ""

    @State private var studyReason = ""

    @State private var intensity = ""

    // MARK: - Options

    private let situationOptions = [
        "I'm working",
        "University student",
        "School student",
        "Something else"
    ]

    private let studyReasonOptions = [
        "Pass an exam",
        "Get certified",
        "Career",
        "Learn something",
        "I have no choice"
    ]

    private let intensityOptions = [
        (
            title: "Go easy on me",
            subtitle: "Keep things comfortable."
        ),
        (
            title: "Keep me balanced",
            subtitle: "Challenge me, but don't destroy me."
        ),
        (
            title: "Push me",
            subtitle: "I can handle it."
        )
    ]

    // MARK: - Body

    var body: some View {

        VStack(spacing: 0) {

            // MARK: - Progress

            progressView
                .padding(.horizontal, 20)
                .padding(.top, 20)


            Spacer()


            // MARK: - Content

            VStack(spacing: 20) {

                stepHeader

                stepContent
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)


            Spacer()


            // MARK: - Navigation

            navigationButton
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(
            Color.appBackground
                .ignoresSafeArea()
        )
        .animation(
            .easeInOut(duration: 0.25),
            value: step
        )
    }


    // MARK: - Progress

    private var progressView: some View {

        HStack(spacing: 8) {

            ForEach(
                0..<4,
                id: \.self
            ) { index in

                Capsule()
                    .fill(
                        index <= step.rawValue
                        ? Color.appAccent
                        : Color.appBorder
                    )
                    .frame(height: 4)
            }
        }
    }


    // MARK: - Header

    @ViewBuilder
    private var stepHeader: some View {

        VStack(spacing: 12) {

            Text(headerTitle)
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 28
                    )
                )
                .foregroundStyle(
                    Color.appTextPrimary
                )
                .multilineTextAlignment(.center)


            Text(headerSubtitle)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 15
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
                .multilineTextAlignment(.center)
        }
    }


    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {

        switch step {

        // MARK: Name

        case .name:

            TextField(
                "Your name",
                text: $name
            )
            .font(
                .custom(
                    "PlusJakartaSans-Medium",
                    size: 17
                )
            )
            .foregroundStyle(
                Color.appTextPrimary
            )
            .padding(.horizontal, 18)
            .frame(height: 58)
            .background(
                Color.appSecondarySurface
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .stroke(
                    Color.appBorder,
                    lineWidth: 1
                )
            }


        // MARK: Current Situation

        case .currentSituation:

            optionList(
                options: situationOptions,
                selection: $currentSituation
            )


        // MARK: Study Reason

        case .studyReason:

            optionList(
                options: studyReasonOptions,
                selection: $studyReason
            )


        // MARK: Intensity

        case .intensity:

            VStack(spacing: 12) {

                ForEach(
                    intensityOptions,
                    id: \.title
                ) { option in

                    Button {

                        intensity = option.title

                    } label: {

                        HStack {

                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {

                                Text(option.title)
                                    .font(
                                        .custom(
                                            "PlusJakartaSans-SemiBold",
                                            size: 16
                                        )
                                    )

                                Text(option.subtitle)
                                    .font(
                                        .custom(
                                            "PlusJakartaSans-Regular",
                                            size: 13
                                        )
                                    )
                                    .foregroundStyle(
                                        Color.appTextSecondary
                                    )
                            }

                            Spacer()

                            Image(
                                systemName:
                                    intensity == option.title
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .font(.system(size: 22))
                        }
                        .foregroundStyle(
                            Color.appTextPrimary
                        )
                        .padding(18)
                        .background(
                            intensity == option.title
                            ? Color.appAccent.opacity(0.12)
                            : Color.appSurface
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 8,
                                style: .continuous
                            )
                        )
                        .overlay {

                            RoundedRectangle(
                                cornerRadius: 8,
                                style: .continuous
                            )
                            .stroke(
                                intensity == option.title
                                ? Color.appAccent
                                : Color.appBorder,
                                lineWidth:
                                    intensity == option.title
                                    ? 2
                                    : 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }


        // MARK: Finished

        case .finished:

            VStack(spacing: 16) {

                Text("Alright, \(name).")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 26
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )

                Text(
                    "I know enough to get started."
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 16
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
            }
        }
    }


    // MARK: - Option List

    private func optionList(
        options: [String],
        selection: Binding<String>
    ) -> some View {

        VStack(spacing: 12) {

            ForEach(
                options,
                id: \.self
            ) { option in

                Button {

                    selection.wrappedValue = option

                } label: {

                    HStack {

                        Text(option)
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 16
                                )
                            )

                        Spacer()

                        Image(
                            systemName:
                                selection.wrappedValue == option
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .font(
                            .system(
                                size: 22
                            )
                        )
                    }
                    .foregroundStyle(
                        Color.appTextPrimary
                    )
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .background(
                        selection.wrappedValue == option
                                ? Color.appAccent.opacity(0.12)
                        : Color.appSurface
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                        .stroke(
                            selection.wrappedValue == option
                            ? Color.appAccent
                            : Color.appBorder,
                            lineWidth:
                                selection.wrappedValue == option
                                ? 2
                                : 1
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }


    // MARK: - Navigation Button

    private var navigationButton: some View {

        Button {

            handleNext()

        } label: {

            HStack {

                Text(buttonTitle)

                Spacer()

                Image(
                    systemName:
                        step == .finished
                        ? "sparkles"
                        : "arrow.right"
                )
            }
            .font(
                .custom(
                    "PlusJakartaSans-Bold",
                    size: 16
                )
            )
            .foregroundStyle(
                stepIsValid
                ? Color.appBackground
                : Color.appTextSecondary
            )
            .padding(.horizontal, 20)
            .frame(height: 58)
            .background(
                stepIsValid
                ? Color.appAccent
                : Color.appSecondarySurface
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!stepIsValid)
    }


    // MARK: - Text

    private var headerTitle: String {

        switch step {

        case .name:
            return "First things first."

        case .currentSituation:
            return "What are you doing right now?"

        case .studyReason:
            return "Why are you studying?"

        case .intensity:
            return "How much can you handle?"

        case .finished:
            return "You're all set."
        }
    }


    private var headerSubtitle: String {

        switch step {

        case .name:
            return "What should I call you?"

        case .currentSituation:
            return "This helps me understand your routine."

        case .studyReason:
            return "Give me a practical reason."

        case .intensity:
            return "How hard should I push you?"

        case .finished:
            return "Let's build something worth studying."
        }
    }


    private var buttonTitle: String {

        switch step {

        case .finished:
            return "Let's go"

        default:
            return "Continue"
        }
    }


    // MARK: - Validation

    private var stepIsValid: Bool {

        switch step {

        case .name:
            return !name
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty

        case .currentSituation:
            return !currentSituation.isEmpty

        case .studyReason:
            return !studyReason.isEmpty

        case .intensity:
            return !intensity.isEmpty

        case .finished:
            return true
        }
    }


    // MARK: - Actions

    private func handleNext() {

        if step == .finished {

            // Map current situation to
            // the existing educationLevel value.

            let educationLevel: String

            switch currentSituation {

            case "I'm working":
                educationLevel = "Working Professional"

            case "University student":
                educationLevel = "University"

            case "School student":
                educationLevel = "School"

            default:
                educationLevel = "Other"
            }

            onComplete(
                name,
                educationLevel,
                studyReason
            )

            return
        }


        step = Step(
            rawValue: step.rawValue + 1
        ) ?? .finished
    }
}