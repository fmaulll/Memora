import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void = {}
    var onLoggedIn: () -> Void = {}

    var body: some View {
        AppBackground {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Text("Welcome to\nMemora")
                    .font(.custom("PlusJakartaSans-ExtraBold", size: 44))
                    .foregroundStyle(Color.appTextPrimary)

                Text("Less staring at notes. More knowing your stuff.")
                    .font(.custom("PlusJakartaSans-Regular", size: 17))
                    .foregroundStyle(Color.appTextSecondary)

                Image("MrEdJudging")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 240)

                Spacer()

                AppButton(
                    title: "Get started",
                    icon: .sf("arrow.right"),
                    iconPosition: .right,
                    foreground: Color.appBackground,
                    background: Color.appAccent,
                    action: onGetStarted
                )

                Text("Preview your first AI deck free. Subscribe to study it.")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                NavigationLink {
                    LoginView(onLoggedIn: onLoggedIn)
                } label: {
                    Text("Already have an account? Log in")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    WelcomeView()
}
