import SwiftUI

struct MrEdOutcomeView: View {
    let isSubscribed: Bool
    let onContinue: () -> Void
    @State private var displayedText = ""
    @State private var dialogueFinished = false

    private var dialogue: [String] {
        if isSubscribed {
            return [
                "Good. Your deck is unlocked.",
                "You paid for a study coach. Not a miracle.",
                "I'll bring the plan. You bring the effort.",
                "Now go make me annoyingly proud."
            ]
        }
        return [
            "Fine. Keep your money. Lose the excuses.",
            "Your AI deck stays here, locked until you subscribe.",
            "You can still make your own decks and study for free.",
            "I'm saying goodbye to the deal. Not your potential.",
            "Go study. I'm still rooting for you. Unfortunately."
        ]
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image("MrEdJudging")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 240)

            Text(displayedText)
                .font(.custom("PlusJakartaSans-Bold", size: 14))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
                .frame(minWidth: 50, minHeight: 54)
                .padding(.horizontal, 20)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                }

            Spacer()

            Button {
                guard dialogueFinished else { return }
                onContinue()
            } label: {
                HStack {
                    Text(isSubscribed ? "Open my deck" : "Go to Home")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.custom("PlusJakartaSans-Bold", size: 16))
                .foregroundStyle(
                    dialogueFinished
                        ? Color.appBackground
                        : Color.appTextSecondary
                )
                .padding(.horizontal, 20)
                .frame(height: 54)
                .background(
                    dialogueFinished
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
            .disabled(!dialogueFinished)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            await playDialogue()
        }
    }

    private func playDialogue() async {
        for (index, line) in dialogue.enumerated() {
            guard !Task.isCancelled else { return }
            displayedText = ""

            for character in line {
                guard !Task.isCancelled else { return }
                displayedText.append(character)

                let delay: UInt64
                switch character {
                case ".", "!", "?": delay = 180_000_000
                case ",": delay = 80_000_000
                case " ": delay = 15_000_000
                default: delay = 40_000_000
                }
                try? await Task.sleep(nanoseconds: delay)
            }

            if index < dialogue.count - 1 {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                displayedText = ""
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        guard !Task.isCancelled else { return }
        dialogueFinished = true
    }
}

struct MrEdSubscribedView: View {
    let onContinue: () -> Void

    var body: some View {
        MrEdOutcomeView(isSubscribed: true, onContinue: onContinue)
    }
}

#Preview {
    MrEdSubscribedView { }
}
