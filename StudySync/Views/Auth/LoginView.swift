import SwiftUI

/// Email + password sign-in, links to Register, optional Google / phone, forgot password.
struct LoginView: View {

    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showPhoneSection = false
    @State private var localMessage: String?
    @State private var localMessageIsError = true

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("StudySync")
                        .font(.system(size: 50, weight: .bold, design: .default))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("Find your study crew")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 22)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Email")
                        .font(.system(size: 18, weight: .semibold))

                    TextField("you@college.edu", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.secondary.opacity(0.45)))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Password")
                        .font(.system(size: 18, weight: .semibold))

                    SecureField("••••••••", text: $password)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.secondary.opacity(0.45)))
                }

                Button {
                    Task { await handleEmailLogin() }
                } label: {
                    Text("Log In")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                }
                .disabled(authViewModel.isLoading)

                HStack(spacing: 16) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(height: 1)
                    Text("or")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(height: 1)
                }
                .padding(.vertical, 2)

                NavigationLink {
                    RegisterView()
                } label: {
                    Text("Create account")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.primary.opacity(0.7), lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button("Forgot password?") {
                    Task { await handleForgotPassword() }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .underline()
                .padding(.top, 8)

                Text("Uses the email above. If the account exists, Firebase will email a reset link.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                providerButtons

                if showPhoneSection {
                    phoneSection
                }

                messageBlock

                if authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 36)

                NavigationLink {
                    RegisterView()
                } label: {
                    HStack(spacing: 6) {
                        Text("Don't have an account?")
                            .foregroundStyle(.secondary)
                        Text("Sign Up")
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 18))
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 26)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private var messageBlock: some View {
        if let notice = authViewModel.transientNotice, !notice.isEmpty {
            Text(notice)
                .font(.footnote)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let message = localMessage, !message.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundStyle(localMessageIsError ? .red : .green)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let error = authViewModel.errorMessage, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var providerButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await authViewModel.signInWithGoogle() }
            } label: {
                Label("Continue with Google", systemImage: "globe")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)

            Button {
                withAnimation {
                    showPhoneSection.toggle()
                }
            } label: {
                Label(showPhoneSection ? "Hide phone login" : "Continue with Phone", systemImage: "phone")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
        }
    }

    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phone Number")
                .font(.subheadline.weight(.semibold))
            TextField("+1 555 123 4567", text: $authViewModel.phoneNumber)
                .keyboardType(.phonePad)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.45)))

            Button("Send Code") {
                Task { await authViewModel.sendPhoneVerificationCode() }
            }
            .buttonStyle(.borderedProminent)

            if authViewModel.isPhoneCodeSent {
                TextField("Verification code", text: $authViewModel.phoneVerificationCode)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.45)))

                Button("Verify and Sign In") {
                    Task { await authViewModel.verifyPhoneCode() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func handleEmailLogin() async {
        localMessage = nil
        authViewModel.clearError()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter your email."
            return
        }
        guard !password.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter your password."
            return
        }

        await authViewModel.signInWithEmail(email: trimmedEmail, password: password)
        // On success, `AuthGateView` shows `ContentView` when `isSignedIn` becomes true.
    }

    private func handleForgotPassword() async {
        localMessage = nil
        authViewModel.clearError()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localMessageIsError = true
            localMessage = "Enter your email above, then tap Forgot password."
            return
        }

        await authViewModel.sendPasswordReset(email: trimmedEmail)
        if authViewModel.errorMessage == nil {
            localMessageIsError = false
            localMessage = nil
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
