import SwiftUI

/// Create account: display name, email, password — wired to Firebase Auth + initial Firestore profile.
struct RegisterView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var localMessage: String?
    @State private var localMessageIsError = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Create account")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.top, 8)

                Text("Add your name so hosts know who you are.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                labeledField(title: "Name", content: {
                    TextField("Alex Rivera", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.secondary.opacity(0.45)))
                })

                labeledField(title: "Email", content: {
                    TextField("you@college.edu", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.secondary.opacity(0.45)))
                })

                labeledField(title: "Password", content: {
                    SecureField("At least 6 characters", text: $password)
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.secondary.opacity(0.45)))
                })

                Button {
                    Task { await submit() }
                } label: {
                    Text("Register")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                }
                .disabled(authViewModel.isLoading)

                if let message = localMessage, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(localMessageIsError ? .red : .green)
                } else if let err = authViewModel.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if authViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 26)
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
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
