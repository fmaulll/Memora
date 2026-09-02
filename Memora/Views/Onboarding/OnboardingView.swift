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

    @State private var currentPage = 0
    @State private var isDialogueFinished = false
    @State private var isShowingFirstDeckSetup = false
    @State private var shouldCreateFirstDeck = false

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
                "I care about results."
            ],
            imageName: "MrEdLeaning",
            buttonTitle: "Continue"
        ),

        OnboardingPage(
            dialogue: [
                "Give me a goal.",
                "I'll help you build a plan.",
                "Create your study decks.",
                "And test what you know."
            ],
            imageName: "MrEdReady",
            buttonTitle: "Continue"
        ),

        OnboardingPage(
            dialogue: [
                "So tell me.",
                "Are you actually serious about studying?"
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

                        shouldCreateFirstDeck = true
                        onboardingStep = .subscribed
                    },
                    onContinueFree: {

                        onboardingStep = .freeGoodbye
                    }
                )


            case .freeGoodbye:

                MrEdGoodbyeView {

                    shouldCreateFirstDeck = false
                    onboardingStep = .studySetup
                }


            case .subscribed:

                MrEdSubscribedView {

                    onboardingStep = .studySetup
                }


            case .studySetup:

                StudentProfileView {
                    name,
                    educationLevel,
                    studyReason in

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


                            if shouldCreateFirstDeck {
                                isShowingFirstDeckSetup = true
                            } else {
                                hasCompletedOnboarding = true
                            }

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


            VStack(spacing: 0) {

                TabView(
                    selection: $currentPage
                ) {

                    ForEach(
                        Array(
                            pages.enumerated()
                        ),
                        id: \.offset
                    ) { index, page in

                        OnboardingPageView(
                            page: page,
                            onDialogueFinished: {

                                isDialogueFinished = true
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(
                    .page(
                        indexDisplayMode: .never
                    )
                )
                .onChange(
                    of: currentPage
                ) { _, _ in

                    isDialogueFinished = false
                }


                // MARK: Bottom Controls

                VStack(spacing: 18) {

                    PageIndicator(
                        numberOfPages: pages.count,
                        currentPage: currentPage
                    )


                    AppButton(
                        title: pages[
                            currentPage
                        ].buttonTitle,
                        icon: .sf(
                            currentPage ==
                            pages.count - 1
                            ? "checkmark"
                            : "arrow.right"
                        ),
                        iconPosition: .right,
                        foreground: Color.appBackground,
                        background: Color.appAccent
                    ) {

                        withAnimation(
                            .easeInOut(
                                duration: 0.3
                            )
                        ) {

                            if currentPage <
                                pages.count - 1 {

                                currentPage += 1

                            } else {

                                onboardingStep =
                                    .paywall
                            }
                        }
                    }
                    .disabled(
                        !isDialogueFinished
                    )
                    .opacity(
                        isDialogueFinished
                        ? 1
                        : 0.45
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .background(
                    Color.appBackground
                )
            }
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

private struct PageIndicator: View {

    let numberOfPages: Int

    let currentPage: Int


    var body: some View {

        HStack(spacing: 8) {

            ForEach(
                0..<numberOfPages,
                id: \.self
            ) { index in

                Capsule()
                    .fill(
                        index == currentPage
                        ? Color.appAccent
                        : Color.appBorder
                    )
                    .frame(
                        width:
                            index == currentPage
                            ? 26
                            : 8,
                        height: 8
                    )
                    .animation(
                        .easeInOut(
                            duration: 0.25
                        ),
                        value: currentPage
                    )
            }
        }
    }
}


// MARK: - Onboarding Page

private struct OnboardingPageView: View {

    let page: OnboardingPage

    let onDialogueFinished: () -> Void


    @State private var displayedText = ""

    @State private var dialogueIndex = 0


    var body: some View {

        VStack(spacing: 0) {

            // MARK: - Mr. Ed

            Spacer()

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: 300,
                    maxHeight: 340
                )
                .padding(
                    .horizontal,
                    32
                )

            Spacer()
                .frame(height: 20)


            // MARK: - Dialogue

            VStack(spacing: 0) {

                Text(displayedText)
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 26
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )
                    .multilineTextAlignment(
                        .center
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 120
                    )
                    .padding(
                        .horizontal,
                        28
                    )
                    .padding(
                        .vertical,
                        30
                    )
            }
            .frame(
                maxWidth: .infinity
            )
            .background(
                Color.appSurface
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 30,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 30
                )
            )
            .overlay(
                alignment: .top
            ) {

                UnevenRoundedRectangle(
                    topLeadingRadius: 30,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 30
                )
                .stroke(
                    Color.appBorder,
                    lineWidth: 1
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .task {

            await playDialogue()
        }
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


        onDialogueFinished()
    }
}


#Preview {

    OnboardingView { _ in

    }
}