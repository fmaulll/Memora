import SwiftUI

struct RegisterView: View {
    private let accent = Color.appAccent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    @State private var isRegistering = false
    @State private var errorMessage: String?
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case email
        case password
        case confirmPassword
    }

    private var canRegister: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        password == confirmPassword
    }

    private var passwordsDoNotMatch: Bool {
        !confirmPassword.isEmpty &&
        password != confirmPassword
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: Header

                    Text("JOIN MEMORA")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 12
                            )
                        )
                        .tracking(1.4)
                        .foregroundStyle(Color.appAccent)
                        .padding(.top, 18)

                    Text("Let's get you\nset up.")
                        .font(
                            .custom(
                                "PlusJakartaSans-ExtraBold",
                                size: 40
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)
                        .tracking(-1)
                        .lineSpacing(-3)
                        .padding(.top, 10)

                    Text(
                        "Create your account and let Mr. Ed turn what you're learning into something you'll actually remember."
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 14
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(3)
                    .padding(.top, 14)

                    // MARK: Form

                    VStack(alignment: .leading, spacing: 18) {

                        formField(
                            label: "Name",
                            icon: "person",
                            placeholder: "Your name",
                            text: $name,
                            field: .name
                        )

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
                            placeholder: "Create a password",
                            text: $password,
                            field: .password
                        )

                        passwordField(
                            label: "Confirm password",
                            placeholder: "Repeat your password",
                            text: $confirmPassword,
                            field: .confirmPassword
                        )
                    }
                    .padding(.top, 32)

                    // MARK: Password Feedback

                    if passwordsDoNotMatch {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(
                                    .system(
                                        size: 13,
                                        weight: .semibold
                                    )
                                )

                            Text("Passwords do not match.")
                                .font(
                                    .custom(
                                        "PlusJakartaSans-Regular",
                                        size: 12
                                    )
                                )
                        }
                        .foregroundStyle(Color.appError)
                        .padding(.top, 10)
                    }

                    // MARK: Error

                    if let errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(
                                    .system(
                                        size: 15,
                                        weight: .semibold
                                    )
                                )
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

                    // MARK: Create Account

                    AppButton(
                        title: isRegistering
                            ? "Creating account..."
                            : "Create Account",
                        foreground: canRegister
                            ? Color.appTextPrimary
                            : Color.appTextSecondary,
                        background: Color.appAccent
                    ) {
                        register()
                    }
                    .disabled(!canRegister || isRegistering)
                    .opacity(canRegister ? 1 : 0.45)
                    .padding(.top, 26)

                    // MARK: Login

                    HStack(spacing: 5) {
                        Text("Already have an account?")
                            .foregroundStyle(Color.appTextSecondary)

                        Button {
                            dismiss()
                        } label: {
                            Text("Log in")
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 14
                                    )
                                )
                                .foregroundStyle(Color.appAccent)
                        }
                        .buttonStyle(.plain)
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
                    .textInputAutocapitalization(
                        keyboardType == .emailAddress
                            ? .never
                            : .words
                    )
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: field)
                    .submitLabel(nextSubmitLabel(for: field))
                    .onSubmit {
                        moveToNextField(from: field)
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
                        passwordBorderColor(for: field)
                    )
                    .frame(width: 20)

                Group {
                    if isVisible(for: field) {
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
                .submitLabel(
                    field == .confirmPassword
                        ? .go
                        : .next
                )
                .onSubmit {
                    if field == .password {
                        focusedField = .confirmPassword
                    } else if canRegister {
                        register()
                    }
                }

                Button {
                    toggleVisibility(for: field)
                } label: {
                    Image(
                        systemName: isVisible(for: field)
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
                        passwordBorderColor(for: field),
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            }
            .animation(
                .easeInOut(duration: 0.15),
                value: focusedField
            )
        }
    }

    // MARK: - Field Helpers

    private func nextSubmitLabel(
        for field: Field
    ) -> SubmitLabel {
        switch field {
        case .name, .email:
            return .next

        case .password:
            return .next

        case .confirmPassword:
            return .go
        }
    }

    private func moveToNextField(
        from field: Field
    ) {
        switch field {
        case .name:
            focusedField = .email

        case .email:
            focusedField = .password

        case .password:
            focusedField = .confirmPassword

        case .confirmPassword:
            if canRegister {
                register()
            }
        }
    }

    private func isVisible(
        for field: Field
    ) -> Bool {
        switch field {
        case .password:
            return isPasswordVisible

        case .confirmPassword:
            return isConfirmPasswordVisible

        default:
            return false
        }
    }

    private func toggleVisibility(
        for field: Field
    ) {
        switch field {
        case .password:
            isPasswordVisible.toggle()

        case .confirmPassword:
            isConfirmPasswordVisible.toggle()

        default:
            break
        }
    }

    private func passwordBorderColor(
        for field: Field
    ) -> Color {

        if field == .confirmPassword &&
            passwordsDoNotMatch {
            return Color.appError
        }

        if focusedField == field {
            return Color.appAccent
        }

        return Color.appBorder
    }

    // MARK: - Register

    private func register() {
        focusedField = nil
        isRegistering = true
        errorMessage = nil

        Task {
            do {
                let user = try await AuthManager.shared.register(
                    name: name,
                    email: email,
                    password: password,
                    modelContext: modelContext
                )

                print("Registered:")
                print(user.name)
                print(user.email)

                await MainActor.run {
                    isRegistering = false
                }

                // Navigate to your main app here.

            } catch {
                await MainActor.run {
                    isRegistering = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
    }
}