import SwiftUI

struct PaywallView: View {

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    var body: some View {

        ZStack {

            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Top Bar

                HStack {

                    Spacer()

                    Button {
                        dismiss()
                    } label: {

                        Image(systemName: "xmark")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.appTextSecondary
                            )
                            .frame(
                                width: 40,
                                height: 40
                            )
                            .background(
                                Color.appSurface,
                                in: Circle()
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)


                Spacer()


                // MARK: - Mr. Ed

                Image("MrEdTrade")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 220)


                // MARK: - Title

                Text("A simple deal.")
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 30
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )
                    .padding(.top, 12)


                Text("You give. You receive.")
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 15
                        )
                    )
                    .foregroundStyle(
                        Color.appTextSecondary
                    )
                    .padding(.top, 6)


                Spacer()
                    .frame(height: 32)


                // MARK: - Trade

                HStack(
                    alignment: .top,
                    spacing: 12
                ) {

                    tradeColumn(
                        title: "YOU GIVE",
                        icon: "dollarsign.circle.fill",
                        text: "$0.99"
                    )

                    VStack(spacing: 6) {

                        Image(
                            systemName: "arrow.left.arrow.right"
                        )
                        .font(
                            .system(
                                size: 20,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            Color.appAccent
                        )

                        Text("TRADE")
                            .font(
                                .custom(
                                    "PlusJakartaSans-Bold",
                                    size: 10
                                )
                            )
                            .foregroundStyle(
                                Color.appTextSecondary
                            )
                    }
                    .frame(width: 60)
                    .padding(.top, 36)

                    tradeColumn(
                        title: "YOU RECEIVE",
                        icon: "brain.head.profile",
                        text: "Mr. Ed"
                    )
                }
                .padding(.horizontal, 20)


                Spacer()
                    .frame(height: 20)


                // MARK: - Features

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    featureRow(
                        icon: "map.fill",
                        text: "Personal study curriculum"
                    )

                    featureRow(
                        icon: "calendar",
                        text: "Smart study timeline"
                    )

                    featureRow(
                        icon: "rectangle.stack.fill",
                        text: "AI-generated flashcards"
                    )

                    featureRow(
                        icon: "checkmark.circle.fill",
                        text: "Chapter exams and practice"
                    )
                }
                .padding(18)
                .background(
                    Color.appSurface,
                    in: RoundedRectangle(
                        cornerRadius: 18
                    )
                )
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .stroke(
                        Color.appBorder,
                        lineWidth: 1
                    )
                }
                .padding(.horizontal, 20)


                Spacer()


                // MARK: - CTA

                AppButton(
                    title: "Accept the deal — $0.99",
                    icon: .sf("arrow.right"),
                    iconPosition: .right,
                    foreground: .black,
                    background: Color.appAccent
                ) {

                    // StoreKit purchase later
                    print("Accept deal")
                }
                .padding(.horizontal, 20)


                Text(
                    "$0.99 for 3 days, then $4.99/month. Cancel anytime."
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 11
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
                .multilineTextAlignment(.center)
                .padding(.top, 10)

                Button("Maybe later") {
                    hasCompletedOnboarding = true
                }
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 13
                    )
                )
                .foregroundStyle(Color.appTextSecondary)
                .padding(.top, 16)
            }
        }
    }


    // MARK: - Trade Column

    private func tradeColumn(
        title: String,
        icon: String,
        text: String
    ) -> some View {

        VStack(spacing: 10) {

            Text(title)
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 10
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )

            Image(systemName: icon)
                .font(
                    .system(
                        size: 26,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.appAccent
                )

            Text(text)
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 20
                    )
                )
                .foregroundStyle(
                    Color.appTextPrimary
                )
        }
        .frame(
            maxWidth: .infinity
        )
    }


    // MARK: - Feature Row

    private func featureRow(
        icon: String,
        text: String
    ) -> some View {

        HStack(spacing: 12) {

            Image(systemName: icon)
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.appAccent
                )
                .frame(width: 22)

            Text(text)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 14
                    )
                )
                .foregroundStyle(
                    Color.appTextPrimary
                )

            Spacer()
        }
    }
}


#Preview {
    PaywallView()
}