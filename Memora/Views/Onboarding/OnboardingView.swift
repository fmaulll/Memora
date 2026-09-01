//
//  OnboardingView.swift
//  Memora
//
//  Created by fuckdazeshit on 13/08/26.
//

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
    @State private var onboardingStep: OnboardingStep = .introduction
    @State private var isDialogueFinished = false
    @State private var isShowingFirstDeckSetup = false

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    private let background = Color(
        red: 0.04,
        green: 0.04,
        blue: 0.13
    )

    private let accent = Color(
        red: 0.39,
        green: 0.40,
        blue: 0.95
    )

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
                "I'll build your curriculum.",
                "Plan your study.",
                "Prepare your cards.",
                "And test your knowledge.",
                "You focus on one thing.",
                "Studying."
            ],
            imageName: "MrEdLeaning",
            buttonTitle: "Continue"
        ),

        OnboardingPage(
            dialogue: [
                "So tell me.",
                "Everyone wants to succeed.",
                "Not everyone wants to do the work.",
                "Are you serious about studying?"
            ],
            imageName: "MrEdJudging",
            buttonTitle: "I'M SERIOUS."
        )
    ]

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
            print("NAME:", name)
            print("EDUCATION:", educationLevel)
            print("REASON:", studyReason)

        } catch {

            print(
                "FAILED TO SAVE LOCAL PROFILE:",
                error.localizedDescription
            )
        }
    }

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

                    onboardingStep = .studySetup
                }

            case .studySetup:

                StudentProfileView {
                    name,
                    educationLevel,
                    studyReason in

                    Task {
                        do {
                            // 1. Save onboarding information locally
                            saveLocalProfile(
                                name: name,
                                educationLevel: educationLevel,
                                studyReason: studyReason
                            )

                            // 2. Create anonymous backend user
                            try await authManager.createAnonymousUser(
                                name: name,
                                modelContext: modelContext
                            )

                            // 3. Continue to first AI deck creation after success
                            isShowingFirstDeckSetup = true

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
        .navigationDestination(isPresented: $isShowingFirstDeckSetup) {
            AIDeckSetupView(
                onDeckCreated: { createdDeck in
                    onFirstDeckCreated(createdDeck)
                    hasCompletedOnboarding = true
                },
                existingDeck: nil
            )
        }
    }

    private var introductionView: some View {
        ZStack(alignment: .topTrailing) {

            AppBackground {
                VStack(spacing: 0) {

                    TabView(selection: $currentPage) {

                        ForEach(
                            Array(pages.enumerated()),
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
                        .page(indexDisplayMode: .never)
                    )
                    .animation(
                        .easeInOut(duration: 0.45),
                        value: currentPage
                    )
                    .onChange(of: currentPage) { _, _ in
                        isDialogueFinished = false
                    }

                    PageIndicator(
                        numberOfPages: pages.count,
                        currentPage: currentPage,
                        accent: .appAccent
                    )
                    .padding(.bottom, 20)

                    AppButton(
                        title: pages[currentPage].buttonTitle,
                        icon: .sf(
                            currentPage == pages.count - 1
                            ? "checkmark"
                            : "chevron.right"
                        ),
                        iconPosition: .right,
                        foreground: .white
                    ) {
                        withAnimation(
                            .easeInOut(duration: 0.45)
                        ) {

                            if currentPage < pages.count - 1 {

                                currentPage += 1

                            } else {

                                onboardingStep = .paywall
                            }
                        }
                    }
                    .disabled(!isDialogueFinished)
                    .opacity(isDialogueFinished ? 1 : 0.45)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            
        }
    }

}



// MARK: - Page Indicator

private struct PageIndicator: View {

    let numberOfPages: Int
    let currentPage: Int
    let accent: Color

    var body: some View {

        HStack(spacing: 8) {

            ForEach(
                0..<numberOfPages,
                id: \.self
            ) { page in

                Capsule()
                    .fill(
                        page == currentPage
                        ? accent
                        : .white.opacity(0.10)
                    )
                    .frame(
                        width: page == currentPage
                        ? 24
                        : 8,
                        height: 8
                    )
                    .animation(
                        .easeInOut(duration: 0.2),
                        value: currentPage
                    )
            }
        }
    }
}


// MARK: - Model

private struct OnboardingPage {

    let dialogue: [String]
    let imageName: String
    let buttonTitle: String
}


private struct OnboardingPageView: View {

    let page: OnboardingPage
    let onDialogueFinished: () -> Void

    @State private var displayedText = ""
    @State private var dialogueIndex = 0

    var body: some View {

        VStack(
            alignment: .center,
            spacing: 20
        ) {

            Spacer()

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 330)

            Text(displayedText)
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 28
                    )
                )
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(
                    minHeight: 80
                )

            Spacer()
                .frame(height: 30)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.horizontal, 20)
        .task {
            await playDialogue()
        }
    }


    // MARK: - Dialogue Animation

    private func playDialogue() async {

        displayedText = ""

        for (index, line) in page.dialogue.enumerated() {

            guard !Task.isCancelled else {
                return
            }

            displayedText = ""

            // Type current dialogue
            for character in line {

                guard !Task.isCancelled else {
                    return
                }

                displayedText.append(character)

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

            // Check if this is the last dialogue
            let isLastLine = index == page.dialogue.count - 1

            if !isLastLine {

                // Let user read it
                try? await Task.sleep(
                    nanoseconds: 1_500_000_000
                )

                guard !Task.isCancelled else {
                    return
                }

                // Remove dialogue before next line
                displayedText = ""

                try? await Task.sleep(
                    nanoseconds: 250_000_000
                )
            }
        }

        guard !Task.isCancelled else {
            return
        }

        // Last dialogue stays visible
        onDialogueFinished()
    }
}


#Preview {
    OnboardingView { _ in
    }
}