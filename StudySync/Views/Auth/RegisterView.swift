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

    private enum Field: Hashable {
        case name
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Create account")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, 8)

                Text("Add your name so hosts know who you are.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                labeledField(title: "Name", content: {
                    TextField("Alex Rivera", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .name ? AppTheme.accent : AppTheme.primary.opacity(0.45), lineWidth: focusedField == .name ? 2.5 : 1.5)
                        )
                })

                labeledField(title: "Email", content: {
                    TextField("you@college.edu", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .email ? AppTheme.accent : AppTheme.primary.opacity(0.45), lineWidth: focusedField == .email ? 2.5 : 1.5)
                        )
                })

                labeledField(title: "Password", content: {
                    SecureField("At least 6 characters", text: $password)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .password)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .password ? AppTheme.accent : AppTheme.primary.opacity(0.45), lineWidth: focusedField == .password ? 2.5 : 1.5)
                        )
                })

                Button {
                    Task { await submit() }
                } label: {
                    Text("Register")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .appPressEffect()
                .disabled(authViewModel.isLoading)

                if let message = localMessage, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(localMessageIsError ? AppTheme.error : AppTheme.accent)
                } else if let err = authViewModel.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.error)
                }

                if authViewModel.isLoading {
                    ProgressView()
                        .tint(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 26)
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .foregroundStyle(AppTheme.textPrimary)
        .appBackground()
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func labeledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
            content()
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
