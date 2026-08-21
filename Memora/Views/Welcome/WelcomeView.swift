import SwiftUI

struct WelcomeView: View {

    @State private var deckID: UUID = UUID()

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)


    var body: some View {
        AppBackground {
            VStack {
                
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Welcome to")
                            .font(.custom("PlusJakartaSans-Regular", size: 48))
                            .kerning(2.88)
                            .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.98))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
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
                    
                    Text("Your personal AI tutor for notes,\nflashcards, and exams.")
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 46)
                
                testField()
                
                VStack(spacing: 20) {
                    NavigationButton(title: "Continue with Apple", icon: .sf("apple.logo"), foreground: .black, background: .white) { }
                    NavigationButton(title: "Continue with Google", icon: .asset("GoogleIcon"), foreground: .white, background: Color(red: 0.02, green: 0.28, blue: 0.65)) { }
                    NavigationButton(title: "Sign up with Email", icon: .sf("envelope.fill"), foreground: .white, background: Color(red: 0.40, green: 0.40, blue: 0.53)) { 
                        RegisterView()
                    }

                    Text("OR")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.vertical, 6)
                    
                    NavigationButton(
                        title: "Continue as Guest",
                        icon: .sf("person.fill")
                    ) {
                        NewStudyDeckView(showsSetUpLater: true)
                    }
                    
                    
                    HStack(spacing: 4) {
                        Text("Have an account?")
                            .foregroundStyle(.white.opacity(0.8))
                        
                        NavigationLink {
                            LoginView()
                        } label: {
                            Text("Login")
                                .foregroundStyle(accent)
                        }
                    }
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    
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
//                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 100)
            .padding(.bottom, 28)
        }
    }


    private func testField() -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Button("Login (Test)") {
                Task {
                    do {
                        let user = try await AuthAPI.shared.login(
                            email: "edi.s@example.com",
                            password: "password123"
                        )

                        print("Logged in:", user.name)

                        print(
                            "Token exists:",
                            KeychainService.shared.hasAccessToken()
                        )

                    } catch {
                        print("Login error:", error)
                    }
                }
            }

            Button("Me (Test)") {
                Task {
                    do {
                        let user = try await AuthAPI.shared.me()

                        print("Current user:")
                        print(user.id)
                        print(user.name)
                        print(user.email)

                    } catch {
                        print("Me error:", error)
                    }
                }
            }
            Button("Create Deck") {
                Task {
                    do {
                        let deck = try await DeckAPI.shared.create(
                            title: "How to make meth",
                            subject: "Chemistry",
                            educationLevel: "Beginner"
                        )

                        print("Created deck:")
                        print(deck.id)
                        print(deck.title)
                        deckID = deck.id

                    } catch {
                        print("Deck error:", error)
                    }
                }
            }


            Button("Get Decks") {
                Task {
                    do {
                        let decks = try await DeckAPI.shared.getAll()

                        print("Deck count:", decks.count)

                        for deck in decks {
                            print(deck.title, deck.id)
                        }

                    } catch {
                        print("Get decks error:", error)
                    }
                }
            }

            Button("Update Deck") {
                Task {
                    do {
                        let updated = try await DeckAPI.shared.update(
                            id: deckID,
                            title: "Meth is awesome"
                        )

                        print("Updated:", updated.title)

                    } catch {
                        print("Update error:", error)
                    }
                }
            }

            Button("Delete Deck") {
                Task {
                    do {
                        try await DeckAPI.shared.delete(
                            id: deckID
                        )

                        print("Deck deleted")

                    } catch {
                        print("Delete error:", error)
                    }
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
