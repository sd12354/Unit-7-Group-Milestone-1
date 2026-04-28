import SwiftUI

/// Create account: display name, email, password — wired to Firebase Auth + initial Firestore profile.
struct RegisterView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var localMessage: String?
    @State private var localMessageIsError = true
    @FocusState private var focusedField: Field?
    @State private var showPassword = false
    /// Keep typed text and placeholder contrast readable on white fields.
    private let inputTextColor = Color(white: 0.38)

    private enum Field: Hashable {
        case name
        case email
        case password
    }

    var body: some View {
        ZStack {
            Image("AppGradientBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 4) {
                        Image("StudySyncLogoTransparent")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .padding(.bottom, 2)
                        Text("Create Account")
                            .font(AppTheme.titleFont)
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("Add your name so hosts know who you are.")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 76)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Name", systemImage: "person.fill")
                            .font(AppTheme.bodyFont.weight(.medium))
                            .foregroundStyle(.white)

                        TextField(
                            "",
                            text: $displayName,
                            prompt: Text("Alex Rivera").foregroundStyle(inputTextColor.opacity(0.65))
                        )
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .foregroundStyle(inputTextColor)
                        .tint(inputTextColor)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .name ? AppTheme.accent : AppTheme.primary.opacity(0.55), lineWidth: focusedField == .name ? 2.5 : 1.5)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Email", systemImage: "envelope.fill")
                            .font(AppTheme.bodyFont.weight(.medium))
                            .foregroundStyle(.white)

                        TextField(
                            "",
                            text: $email,
                            prompt: Text("johndoe@gmail.com").foregroundStyle(inputTextColor.opacity(0.65))
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .foregroundStyle(inputTextColor)
                        .tint(inputTextColor)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .email ? AppTheme.accent : AppTheme.primary.opacity(0.55), lineWidth: focusedField == .email ? 2.5 : 1.5)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Password", systemImage: "lock.fill")
                            .font(AppTheme.bodyFont.weight(.medium))
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField(
                                        "",
                                        text: $password,
                                        prompt: Text("At least 6 characters").foregroundStyle(inputTextColor.opacity(0.65))
                                    )
                                } else {
                                    SecureField(
                                        "",
                                        text: $password,
                                        prompt: Text("At least 6 characters").foregroundStyle(inputTextColor.opacity(0.65))
                                    )
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .password)
                            .foregroundStyle(inputTextColor)
                            .tint(inputTextColor)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(AppTheme.primary.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .password ? AppTheme.accent : AppTheme.primary.opacity(0.55), lineWidth: focusedField == .password ? 2.5 : 1.5)
                        )
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text("Register")
                            .font(AppTheme.labelFont)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .appPressEffect()
                    .disabled(authViewModel.isLoading)

                    if let message = localMessage, !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(localMessageIsError ? AppTheme.error : AppTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let err = authViewModel.errorMessage, !err.isEmpty {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func submit() async {
        localMessage = nil
        authViewModel.clearError()

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter your name."
            return
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter your email."
            return
        }

        guard password.count >= 6 else {
            localMessageIsError = true
            localMessage = "Password must be at least 6 characters."
            return
        }

        await authViewModel.registerWithEmail(displayName: trimmedName, email: trimmedEmail, password: password)

        if authViewModel.errorMessage == nil {
            localMessageIsError = false
            localMessage = "Welcome! Opening the app…"
            // AuthGateView replaces this flow with ContentView when `isSignedIn` becomes true.
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
