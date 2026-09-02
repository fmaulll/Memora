import SwiftUI

struct MrEdGoodbyeView: View {

    let onContinue: () -> Void

    @State private var displayedText = ""
    @State private var dialogueFinished = false


    private let dialogue = [
        "Fine.",
        "You don't need to pay me to start studying.",
        "But I can't help someone I know nothing about.",
        "So let's fix that."
    ]


    var body: some View {

        ZStack {

            Color.appBackground
                .ignoresSafeArea()


            VStack(spacing: 0) {

                // MARK: - Main Content

                VStack(spacing: 0) {

                    Spacer()


                    // MARK: - Mr. Ed

                    Image("MrEdJudging")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: 300,
                            maxHeight: 340
                        )
                        .padding(.horizontal, 32)


                    Spacer()
                        .frame(height: 20)


                    // MARK: - Dialogue Card

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
                            .multilineTextAlignment(.center)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 120
                            )
                            .padding(.horizontal, 28)
                            .padding(.vertical, 30)
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


                // MARK: - Bottom Controls

                VStack(spacing: 18) {

                    AppButton(
                        title: "Alright. Ask away.",
                        icon: .sf("arrow.right"),
                        iconPosition: .right,
                        foreground: Color.appBackground,
                        background: Color.appAccent
                    ) {

                        onContinue()
                    }
                    .disabled(
                        !dialogueFinished
                    )
                    .opacity(
                        dialogueFinished
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

                guard !Task.isCancelled else {
                    return
                }

                displayedText = ""

                try? await Task.sleep(
                    nanoseconds: 250_000_000
                )
            }
        }

        guard !Task.isCancelled else {
            return
        }

        dialogueFinished = true
    }
}


#Preview {

    MrEdGoodbyeView {

    }
}