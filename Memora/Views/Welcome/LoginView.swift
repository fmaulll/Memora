import SwiftUI

struct LoginView: View {
    var onLoggedIn: (() -> Void)? = nil

    private let accent = Color.appAccent

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
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Header

                    Text("WELCOME BACK")
                        .font(.custom("PlusJakartaSans-Bold", size: 12))
                        .tracking(1.4)
                        .foregroundStyle(Color.appAccent)
                        .padding(.top, 18)

                    Text("Good to see\nyou again.")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                        .foregroundStyle(Color.appTextPrimary)
                        .tracking(-1)
                        .lineSpacing(-3)
                        .padding(.top, 10)

                    Text("Log in and get back to studying. Mr. Ed has been waiting.")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                        .lineSpacing(3)
                        .padding(.top, 14)

                    // MARK: Form

                    VStack(alignment: .leading, spacing: 18) {

                        formField(
                            label: "Email",
                            icon: "envelope",
                            placeholder: "you@example.com",
                            text: $email,
                            field: .email,
                            keyboardType: .emailAddress
                        )

                        passwordField(
                            label: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            field: .password
                        )

                        HStack {
                            Spacer()

                            Button("Forgot password?") {
                                // Navigate to ForgotPasswordView
                            }
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 13
                                )
                            )
                            .foregroundStyle(accent)
                        }
                    }
                    .padding(.top, 32)

                    // MARK: Error

                    if let errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appError)

                            Text(errorMessage)
                                .font(
                                    .custom(
                                        "PlusJakartaSans-Regular",
                                        size: 13
                                    )
                                )
                                .foregroundStyle(Color.appTextSecondary)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                        .padding(14)
                        .background(
                            Color.appError.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    Color.appError.opacity(0.25),
                                    lineWidth: 1
                                )
                        }
                        .padding(.top, 18)
                    }

                    // MARK: Login Button

                    AppButton(
                        title: isLoggingIn
                            ? "Logging in..."
                            : "Log In",
                        foreground: canLogin
                            ? Color.appTextPrimary
                            : Color.appTextSecondary,
                        background: Color.appAccent
                    ) {
                        login()
                    }
                    .disabled(!canLogin || isLoggingIn)
                    .opacity(canLogin ? 1 : 0.45)
                    .padding(.top, 26)

                    divider
                        .padding(.top, 30)

                    // MARK: Social Login

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
                            background: Color(
                                red: 0.02,
                                green: 0.28,
                                blue: 0.65
                            )
                        ) {
                            // Google Sign In
                        }
                    }
                    .padding(.top, 20)

                    // MARK: Register

                    HStack(spacing: 5) {
                        Text("Don't have an account?")
                            .foregroundStyle(Color.appTextSecondary)

                        NavigationLink {
                            RegisterView()
                        } label: {
                            Text("Sign up")
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 14
                                    )
                                )
                                .foregroundStyle(accent)
                        }
                    }
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 14
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)

                    Color.clear
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BackNavigationBar {
                    EmptyView()
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
    }

    // MARK: - Form Field

    private func formField(
        label: String,
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default
    ) -> some View {

        VStack(alignment: .leading, spacing: 9) {

            Text(label)
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 13
                    )
                )
                .foregroundStyle(
                    focusedField == field
                        ? Color.appTextPrimary
                        : Color.appTextSecondary
                )

            HStack(spacing: 12) {

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        focusedField == field
                            ? accent
                            : Color.appTextSecondary
                    )
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 15
                        )
                    )
                    .foregroundStyle(Color.appTextPrimary)
                    .tint(accent)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(.next)
                    .onSubmit {
                        if field == .email {
                            focusedField = .password
                        }
                    }

                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                Color.appTextSecondary.opacity(0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        focusedField == field
                            ? accent
                            : Color.appBorder,
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            }
            .animation(
                .easeInOut(duration: 0.15),
                value: focusedField
            )
        }
    }

    // MARK: - Password Field

    private func passwordField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {

        VStack(alignment: .leading, spacing: 9) {

            Text(label)
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 13
                    )
                )
                .foregroundStyle(
                    focusedField == field
                        ? Color.appTextPrimary
                        : Color.appTextSecondary
                )

            HStack(spacing: 12) {

                Image(systemName: "lock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        focusedField == field
                            ? accent
                            : Color.appTextSecondary
                    )
                    .frame(width: 20)

                Group {
                    if isPasswordVisible {
                        TextField(
                            placeholder,
                            text: text
                        )
                    } else {
                        SecureField(
                            placeholder,
                            text: text
                        )
                    }
                }
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 15
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .tint(accent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: field)
                .submitLabel(.go)
                .onSubmit {
                    if canLogin {
                        login()
                    }
                }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(
                        systemName: isPasswordVisible
                            ? "eye.slash"
                            : "eye"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        focusedField == field
                            ? Color.appTextPrimary
                            : Color.appTextSecondary
                    )
                    .frame(
                        width: 36,
                        height: 44
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .frame(height: 54)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        focusedField == field
                            ? accent
                            : Color.appBorder,
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            }
            .animation(
                .easeInOut(duration: 0.15),
                value: focusedField
            )
        }
    }

    // MARK: - Divider

    private var divider: some View {
        HStack(spacing: 14) {

            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 1)

            Text("OR")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .tracking(1)
                .foregroundStyle(Color.appTextSecondary)

            Rectangle()
                .fill(Color.appBorder)
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

                    if let onLoggedIn {
                        onLoggedIn()
                    } else {
                        dismiss()
                    }
                }

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
    NavigationStack {
        LoginView()
    }
}