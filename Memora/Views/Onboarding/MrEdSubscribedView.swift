import SwiftUI

struct MrEdSubscribedView: View {

    let onContinue: () -> Void

    @State private var displayedText = ""
    @State private var dialogueFinished = false

    private let dialogue = [
        "Good.",
        "Now we're getting somewhere.",
        "If I'm going to help you succeed...",
        "...I need to know who I'm dealing with."
    ]

    var body: some View {

        ZStack(alignment: .topTrailing) {


            AppBackground {
                VStack(spacing: 0) {

                    Spacer()

                    Image("MrEdJudging")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 330)

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
                            minHeight: 100
                        )
                        .padding(.horizontal, 30)
                        .padding(.bottom, 20)

                    AppButton(
                        title: "Alright. Ask away.",
                        icon: .sf("arrow.right"),
                        iconPosition: .right,
                        foreground: .black,
                        background: Color.appAccent
                    ) {
                        onContinue()
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

    MrEdSubscribedView {

    }
}