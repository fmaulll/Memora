import SwiftUI
import SwiftData

private enum OnboardingStep {
    case introduction
    case paywall
    case freeGoodbye
    case subscribed
    case studySetup
}

struct OnboardingView: View {

    let onFirstDeckCreated: (StudyDeck) -> Void

    @Environment(\.modelContext)
    private var modelContext

    @State private var authManager = AuthManager.shared

    @State private var isDialogueFinished = false
    @State private var isShowingFirstDeckSetup = false

    @State private var onboardingStep: OnboardingStep = .introduction

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false


    // MARK: - Pages

    private let pages = [

        OnboardingPage(
            dialogue: [
                "I'm Mr. Ed.",
                "Your new study coach.",
                "I don't care about excuses.",
                "I care about results.",
                "Give me a goal.",
                "I'll help you build a plan.",
                "Create your study decks.",
                "And test what you know.",
                "Now...",
                "Let's get started.",
            ],
            imageName: "MrEdJudging",
            buttonTitle: "I'm serious"
        )
    ]


    // MARK: - Save Local Profile

    private func saveLocalProfile(
        name: String,
        educationLevel: String,
        studyReason: String
    ) {

        let profile = LocalUserProfile(
            id: UUID(),
            name: name,
            email: "",
            educationLevel: educationLevel,
            studyReason: studyReason,
            createdAt: Date()
        )

        modelContext.insert(profile)

        do {

            try modelContext.save()

            print("LOCAL PROFILE SAVED")

        } catch {

            print(
                "FAILED TO SAVE LOCAL PROFILE:",
                error.localizedDescription
            )
        }
    }


    // MARK: - Body

    var body: some View {

        Group {

            switch onboardingStep {

            case .introduction:

                introductionView


            case .paywall:

                PaywallView(
                    onSubscribed: {

                        onboardingStep = .subscribed
                    },
                    onContinueFree: {

                        onboardingStep = .freeGoodbye
                    }
                )


            case .freeGoodbye:

                MrEdGoodbyeView {

                    hasCompletedOnboarding = true
                }


            case .subscribed:

                MrEdSubscribedView {

                    isShowingFirstDeckSetup = true
                }


            case .studySetup:

                StudentProfileView {
                    name,
                    educationLevel,
                    studyReason in

                    onboardingStep = .paywall

                    Task {

                        do {

                            // Save profile locally

                            saveLocalProfile(
                                name: name,
                                educationLevel: educationLevel,
                                studyReason: studyReason
                            )


                            // Create anonymous backend user

                            try await authManager
                                .createAnonymousUser(
                                    name: name,
                                    modelContext: modelContext
                                )


                        } catch {

                            print(
                                "FAILED TO CREATE ANONYMOUS USER:",
                                error
                            )
                        }
                    }
                }
            }
        }
        .navigationDestination(
            isPresented: $isShowingFirstDeckSetup
        ) {

            AIDeckSetupView(
                onDeckCreated: { createdDeck in

                    onFirstDeckCreated(
                        createdDeck
                    )

                    hasCompletedOnboarding = true
                },
                existingDeck: nil
            )
        }
    }


    // MARK: - Introduction

    private var introductionView: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            OnboardingPageView(
                page: pages[0],
                onDialogueFinished: {
                    isDialogueFinished = true
                },
                onContinue: {
                    onboardingStep = .studySetup
                }
            )
        }
    }
}


// MARK: - Page Model

private struct OnboardingPage {

    let dialogue: [String]

    let imageName: String

    let buttonTitle: String
}


// MARK: - Page Indicator

// MARK: - Onboarding Page

private struct OnboardingPageView: View {

    let page: OnboardingPage

    let onDialogueFinished: () -> Void
    let onContinue: () -> Void


    @State private var displayedText = ""

    @State private var dialogueIndex = 0
    @State private var isDialogueFinished = false


    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 240)

            Text(displayedText)
                .font(.custom("PlusJakartaSans-Bold", size: 14))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
                .frame(minWidth: 50, minHeight: 54)
                .padding(.horizontal, 20)
                .background(
                    Color.appSurface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                }

            Spacer()

            // MARK: Bottom Controls

            VStack(spacing: 18) {

                Button {
                    guard isDialogueFinished else { return }
                    onContinue()
                } label: {
                    HStack {
                        Text("Continue")

                        Spacer()

                        Image(systemName: "arrow.right")
                    }
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 16
                        )
                    )
                    .foregroundStyle(
                        isDialogueFinished
                            ? Color.appBackground
                            : Color.appTextSecondary
                    )
                    .padding(.horizontal, 20)
                    .frame(height: 54)
                    .background(
                        isDialogueFinished
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
                .disabled(
                    !isDialogueFinished
                )
            }
            .padding(.bottom, 20)
            .background(
                Color.appBackground
            )
        }
        .padding(.horizontal, 20)
        .task { await playDialogue() }
    }


    // MARK: - Dialogue Animation

    private func playDialogue() async {

        displayedText = ""

        for (
            index,
            line
        ) in page.dialogue.enumerated() {

            guard !Task.isCancelled else {
                return
            }


            displayedText = ""


            // MARK: Type Text

            for character in line {

                guard !Task.isCancelled else {
                    return
                }


                displayedText.append(
                    character
                )


                let delay: UInt64


                switch character {

                case ".", "!", "?":

                    delay = 180_000_000


                case ",", ":":

                    delay = 80_000_000


                case " ":

                    delay = 15_000_000


                default:

                    delay = 40_000_000
                }


                try? await Task.sleep(
                    nanoseconds: delay
                )
            }


            let isLastLine =
                index ==
                page.dialogue.count - 1


            if !isLastLine {

                try? await Task.sleep(
                    nanoseconds:
                        1_300_000_000
                )


                guard !Task.isCancelled else {
                    return
                }


                displayedText = ""


                try? await Task.sleep(
                    nanoseconds:
                        200_000_000
                )
            }
        }


        guard !Task.isCancelled else {
            return
        }

        isDialogueFinished = true
        onDialogueFinished()
    }
}


#Preview {

    OnboardingView { _ in

    }
}
