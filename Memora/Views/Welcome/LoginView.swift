import SwiftUI

struct LoginView: View {
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    @State private var isPasswordVisible = false
    
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        HStack {
                            BackButton()
                            Spacer()
                        }

                        Text("Good to see\nyou again.")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 16) {

                            formField(
                                label: "EMAIL",
                                placeholder: "you@example.com",
                                text: $email,
                                field: .email,
                                keyboardType: .emailAddress
                            )

                            passwordField(
                                label: "PASSWORD",
                                placeholder: "Enter your password",
                                text: $password,
                                field: .password
                            )

                            HStack {
                                Spacer()

                                Button("Forgot password?") {
                                    // Navigate to ForgotPasswordView
                                }
                                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                                .foregroundStyle(accent)
                            }
                            .padding(.top, -4)

                        }
                        .padding(.top, 32)

                        AppButton(
                            title: isLoggingIn ? "Logging in..." : "Log In",
                            foreground: canLogin ? .white : .white.opacity(0.45),
                            background: AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        accent,
                                        Color(red: 0.55, green: 0.36, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        ) {
                            login()
                        }
                        .disabled(!canLogin || isLoggingIn)
                        .padding(.top, 28)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.custom("PlusJakartaSans-Regular", size: 14))
                                .foregroundStyle(.red.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 14)
                        }

                        divider
                            .padding(.top, 28)

                        VStack(spacing: 12) {
                            NavigationButton(
                                title: "Continue with Apple",
                                icon: .sf("apple.logo"),
                                foreground: .black,
                                background: .white
                            ) {
                                // Apple Sign In
                            }

                            NavigationButton(
                                title: "Continue with Google",
                                icon: .asset("GoogleIcon"),
                                foreground: .white,
                                background: Color(red: 0.02, green: 0.28, blue: 0.65)
                            ) {
                                // Google Sign In
                            }
                        }
                        .padding(.top, 20)

                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.white.opacity(0.8))

                            NavigationLink {
                                RegisterView()
                            } label: {
                                Text("Login")
                                    .foregroundStyle(accent)
                            }
                            .foregroundStyle(accent)
                        }
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)

                        Color.clear
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .dismissKeyboardOnTap()
    }

    // MARK: - Form Field

    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.62))

            TextField(placeholder, text: text)
                .font(.custom("PlusJakartaSans-Regular", size: 16))
                .foregroundStyle(.white)
                .tint(accent)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .padding(.horizontal, 15)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Rectangle())
                .background(
                    .white.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.28), lineWidth: 1.03)
                }
        }
    }

    // MARK: - Password Field

    private func passwordField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.62))

            HStack(spacing: 0) {
                Group {
                    if isPasswordVisible {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .font(.custom("PlusJakartaSans-Regular", size: 16))
                .foregroundStyle(.white)
                .tint(accent)
                .focused($focusedField, equals: field)

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 15)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                .white.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.28), lineWidth: 1.03)
            }
        }
    }

    // MARK: - Divider

    private var divider: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 1)

            Text("OR")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.55))

            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 1)
        }
    }

    // MARK: - Login

    private func login() {
        focusedField = nil
        isLoggingIn = true
        errorMessage = nil

        Task {
            do {
                let user = try await AuthManager.shared.login(
                    email: email,
                    password: password,
                    modelContext: modelContext
                )

                print("Logged in:", user.name)
                print(
                    "Token exists:",
                    KeychainService.shared.hasAccessToken()
                )

                await MainActor.run {
                    isLoggingIn = false
                }

                // Navigate to your main app here.

            } catch {
                await MainActor.run {
                    isLoggingIn = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LoginView()
}