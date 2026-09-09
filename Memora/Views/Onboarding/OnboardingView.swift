import SwiftUI
import SwiftData

private enum OnboardingStep {
    case introduction
    case profile
    case paywall
    case outcome
}

struct OnboardingView: View {
    let onFirstDeckCreated: (StudyDeck) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var decks: [StudyDeck]
    @State private var authManager = AuthManager.shared
    @State private var onboardingStep: OnboardingStep = .introduction
    @State private var isShowingFirstDeckSetup = false
    @State private var isCreatingAccount = false
    @State private var didCheckSavedDeck = false
    @State private var errorMessage: String?
    @State private var firstDeck: StudyDeck?
    @State private var subscribed = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let introduction = OnboardingPage(
        dialogue: [
            "I'm Mr. Ed. Your study coach.",
            "I care about results. Yours, unfortunately.",
            "Give me a goal. I'll build your first deck.",
            "Preview it free. Subscribe when you're ready to study it.",
            "Now. Let's see what we're working with."
        ],
        imageName: "MrEdJudging",
        buttonTitle: "I'm serious"
    )

    var body: some View {
        Group {
            switch onboardingStep {
            case .introduction:
                OnboardingPageView(
                    page: introduction,
                    onDialogueFinished: {},
                    onContinue: { onboardingStep = .profile }
                )
                .background(Color.appBackground.ignoresSafeArea())

            case .profile:
                StudentProfileView(isSubmitting: isCreatingAccount) { name, educationLevel, studyReason in
                    createProfile(name: name, educationLevel: educationLevel, studyReason: studyReason)
                }

            case .paywall:
                PaywallView(
                    onSubscribed: {
                        subscribed = true
                        onboardingStep = .outcome
                    },
                    onContinueFree: {
                        subscribed = false
                        onboardingStep = .outcome
                    },
                    deckTitle: firstDeck?.title
                )

            case .outcome:
                MrEdOutcomeView(isSubscribed: subscribed) {
                    if subscribed, let firstDeck {
                        onFirstDeckCreated(firstDeck)
                    }
                    hasCompletedOnboarding = true
                }
            }
        }
        .navigationBarBackButtonHidden()
        .background(Color.appBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $isShowingFirstDeckSetup) {
            AIDeckSetupView(
                onDeckCreated: { deck in
                    firstDeck = deck
                    onboardingStep = .paywall
                    isShowingFirstDeckSetup = false
                },
                existingDeck: nil,
                requiresSubscription: true
            )
        }
        .alert("Couldn't get things ready", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .onAppear {
            guard !didCheckSavedDeck else { return }
            didCheckSavedDeck = true

            #if DEBUG
            if UserDefaults.standard.bool(forKey: "developerReplayOnboarding") { return }
            #endif
            // A generated deck remains available if the app closes at the paywall.
            if let savedDeck = decks.first(where: {
                $0.requiresSubscription && $0.parentDeck == nil && !$0.needsDeletion
            }) {
                firstDeck = savedDeck
                onboardingStep = .paywall
            }
        }
    }

    private func createProfile(name: String, educationLevel: String, studyReason: String) {
        guard !isCreatingAccount else { return }
        isCreatingAccount = true

        Task { @MainActor in
            defer { isCreatingAccount = false }
            do {
                // Retrying onboarding must not create another anonymous account.
                if !authManager.isAuthenticated {
                    try await authManager.createAnonymousUser(name: name, modelContext: modelContext)
                }

                if authManager.currentUser == nil {
                    authManager.currentUser = try await AuthAPI.shared.me()
                }

                let profiles = try modelContext.fetch(FetchDescriptor<LocalUserProfile>())
                let userID = authManager.currentUser?.id
                let profile = profiles.first(where: { $0.userId == userID })
                    ?? LocalUserProfile(name: name, createdAt: Date())
                if profile.modelContext == nil { modelContext.insert(profile) }
                profile.userId = userID ?? profile.userId
                profile.name = name
                profile.educationLevel = educationLevel
                profile.studyReason = studyReason
                try modelContext.save()

                #if DEBUG
                if UserDefaults.standard.bool(forKey: "developerReplayOnboarding") {
                    UserDefaults.standard.removeObject(forKey: "developerReplayOnboarding")
                    hasCompletedOnboarding = true
                    return
                }
                #endif
                isShowingFirstDeckSetup = true
            } catch {
                errorMessage = error.localizedDescription
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
