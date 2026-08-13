import SwiftUI

struct ContentView: View {
    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

    var body: some View {
        ZStack {
            
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Welcome to")
                            .font(.custom("PlusJakartaSans-Regular", size: 48))
                            .kerning(2.88)
                            .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.98))
                            .frame(width: 362, alignment: .topLeading)

                        Text("Memora")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
//                    Text("Welcome to\nMemoraa")
//                        .font(.custom("PlusJakartaSans-Bold", size: 46))
//                        .tracking(1.2)
//                        .multilineTextAlignment(.center)
//                        .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.98))

                    Text("Your personal AI tutor for notes, flashcards, and exams.")
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 46)

                VStack(spacing: 20) {
                    WelcomeButton(title: "Continue with Apple", icon: .sf("apple.logo"), foreground: .black, background: .white) { }
                    WelcomeButton(title: "Continue with Google", icon: .asset("GoogleIcon"), foreground: .white, background: Color(red: 0.02, green: 0.28, blue: 0.65)) { }
                    WelcomeButton(title: "Sign up with Email", icon: .sf("envelope.fill"), foreground: .white, background: Color(red: 0.40, green: 0.40, blue: 0.53)) { }

                    Text("OR")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.vertical, 6)

                    
                    WelcomeButton(title: "Continue as Guest", icon: .sf("person.fill"), foreground: .white, background: (accent)) { }
                    

                    HStack(spacing: 4) {
                        Text("Have an account?")
                            .foregroundStyle(.white.opacity(0.8))

                        Button("Login") { }
                            .foregroundStyle(accent)
                    }
                    .font(.custom("PlusJakartaSans-Regular", size: 16))

                    (
                        Text("By continuing, you agree to our ")
                            .foregroundStyle(.white.opacity(0.55))
                        + Text("Terms of Service")
                            .foregroundStyle(accent)
                        + Text(" and ")
                            .foregroundStyle(.white.opacity(0.55))
                        + Text("Privacy Policy")
                            .foregroundStyle(accent)
                    )
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity) // important
                    .fixedSize(horizontal: false, vertical: true) // prevents truncation
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 100)
            .padding(.bottom, 28)
        }
    }
}

private struct WelcomeButton: View {
    enum Icon {
        case sf(String)
        case asset(String)
    }

    let title: String
    let icon: Icon
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {

                switch icon {
                case .sf(let name):
                    Image(systemName: name)
                        .font(.system(size: 20))

                case .asset(let name):
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }

                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .foregroundStyle(foreground)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
