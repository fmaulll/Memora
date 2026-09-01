import SwiftUI

struct MrEdGoodbyeView: View {

    let onFinish: () -> Void

    @State private var displayedText = ""
    @State private var dialogueFinished = false

    private let dialogue = [
        "Fine.",
        "You're on your own.",
        "You can still make your own decks.",
        "But don't expect me to do the work for you."
    ]

    var body: some View {

        ZStack {

            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                Spacer()

                Image("MrEdJudging")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 280)

                Spacer()
                    .frame(height: 32)

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
                        minHeight: 90
                    )
                    .padding(.horizontal, 30)

                Spacer()

                AppButton(
                    title: "Fine. I'll do it myself.",
                    icon: .sf("arrow.right"),
                    iconPosition: .right,
                    foreground: .black,
                    background: Color.appAccent
                ) {
                    onFinish()
                }
                .disabled(!dialogueFinished)
                .opacity(
                    dialogueFinished
                        ? 1
                        : 0.45
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .task {
            await playDialogue()
        }
    }


    // MARK: - Dialogue

    private func playDialogue() async {

        for (index, line) in dialogue.enumerated() {

            guard !Task.isCancelled else {
                return
            }

            displayedText = ""

            for character in line {

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
                    delay = 40_000_000
                }

                try? await Task.sleep(
                    nanoseconds: delay
                )
            }

            let isLastLine =
                index == dialogue.count - 1

            if !isLastLine {

                try? await Task.sleep(
                    nanoseconds: 1_400_000_000
                )

                displayedText = ""

                try? await Task.sleep(
                    nanoseconds: 250_000_000
                )
            }
        }

        dialogueFinished = true
    }
}


#Preview {

    MrEdGoodbyeView {

    }
}