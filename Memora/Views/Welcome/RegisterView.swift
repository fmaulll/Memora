import SwiftUI

struct RegisterView: View {
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

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

    var body: some View {
        ZStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {


                        Text("Create your\nMemora account.")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)

                        VStack(spacing: 16) {

                            formField(
                                label: "NAME",
                                placeholder: "Your name",
                                text: $name,
                                field: .name
                            )

                            formField(
                                label: "EMAIL",
                                placeholder: "you@example.com",
                                text: $email,
                                field: .email,
                                keyboardType: .emailAddress
                            )

                            passwordField(
                                label: "PASSWORD",
                                placeholder: "Create a password",
                                text: $password,
                                field: .password
                            )

                            passwordField(
                                label: "CONFIRM PASSWORD",
                                placeholder: "Repeat your password",
                                text: $confirmPassword,
                                field: .confirmPassword
                            )
                        }
                        .padding(.top, 32)

                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match.")
                                .font(.custom("PlusJakartaSans-Regular", size: 14))
                                .foregroundStyle(.red.opacity(0.9))
                                .padding(.top, -10)
                        }

                        AppButton(
                            title: isRegistering ? "Creating account..." : "Create Account",
                            foreground: canRegister ? .white : .white.opacity(0.45),
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
                            register()
                        }
                        .disabled(!canRegister || isRegistering)
                        .padding(.top, 28)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.custom("PlusJakartaSans-Regular", size: 14))
                                .foregroundStyle(.red.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 14)
                        }

                    }
                    .padding(.horizontal, 20)
                }
                
                .safeAreaInset(edge: .top, spacing: 0) {
                    BackNavigationBar {
                        EmptyView()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        // .dismissKeyboardOnTap()
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
                .textInputAutocapitalization(
                    keyboardType == .emailAddress ? .never : .words
                )
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
                    if field == .password {
                        if isPasswordVisible {
                            TextField(placeholder, text: text)
                        } else {
                            SecureField(placeholder, text: text)
                        }
                    } else {
                        if isConfirmPasswordVisible {
                            TextField(placeholder, text: text)
                        } else {
                            SecureField(placeholder, text: text)
                        }
                    }
                }
                .font(.custom("PlusJakartaSans-Regular", size: 16))
                .foregroundStyle(.white)
                .tint(accent)
                .focused($focusedField, equals: field)

                Button {
                    if field == .password {
                        isPasswordVisible.toggle()
                    } else {
                        isConfirmPasswordVisible.toggle()
                    }
                } label: {
                    Image(
                        systemName: eyeIcon(for: field)
                    )
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

    private func eyeIcon(for field: Field) -> String {
        if field == .password {
            return isPasswordVisible ? "eye.slash" : "eye"
        } else {
            return isConfirmPasswordVisible ? "eye.slash" : "eye"
        }
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
    RegisterView()
}
