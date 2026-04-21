import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showPhoneSection = false
    @State private var showForgotPasswordHint = false
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

                Button {
                    Task { await handleCreateAccount() }
                } label: {
                    Text("Create Account")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.primary.opacity(0.7), lineWidth: 2))
                }
                .disabled(authViewModel.isLoading)

                Button("Forgot password?") {
                    showForgotPasswordHint.toggle()
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .underline()
                .padding(.top, 8)

                if showForgotPasswordHint {
                    Text("Reset can be added next using `sendPasswordReset(withEmail:)` from Firebase Auth.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                providerButtons

                if showPhoneSection {
                    phoneSection
                }

                if let message = localMessage, !message.isEmpty {
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

                if authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 36)

                HStack(spacing: 6) {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    Text("Sign Up")
                        .fontWeight(.bold)
                }
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

            SignInWithAppleButton { request in
                authViewModel.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task {
                    await authViewModel.handleAppleSignIn(result: result)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)

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
    }

    private func handleCreateAccount() async {
        localMessage = nil
        authViewModel.clearError()

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localMessageIsError = true
            localMessage = "Please enter an email for your new account."
            return
        }
        guard password.count >= 6 else {
            localMessageIsError = true
            localMessage = "Password must be at least 6 characters."
            return
        }

        await authViewModel.createAccountWithEmail(email: trimmedEmail, password: password)

        if authViewModel.errorMessage == nil {
            localMessageIsError = false
            localMessage = "Account created. You are now signed in."
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
