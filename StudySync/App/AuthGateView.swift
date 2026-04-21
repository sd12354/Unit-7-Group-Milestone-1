import SwiftUI
import FirebaseAuth

/// Auth gate — shows guest entry when signed out, ContentView when signed in.
/// Replace guest flow with email/password LoginView in Milestone 1 (Issue 2).
struct AuthGateView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                // TODO (Issue 2): Replace with real LoginView
                PlaceholderLoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

/// Stand-in until Issue 2 email/password UI ships. Anonymous sign-in unblocks Milestone 2 session flows.
private struct PlaceholderLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var guestError: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("StudySync")
                .font(.largeTitle.weight(.bold))

            Text("Email login is coming in Milestone 1 (Issue 2). For now, continue as a guest to try sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                Task { await signInGuest() }
            } label: {
                if isSigningIn {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue as guest")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)
            .padding(.horizontal, 40)

            if let guestError {
                Text(guestError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func signInGuest() async {
        isSigningIn = true
        guestError = nil
        defer { isSigningIn = false }
        do {
            _ = try await Auth.auth().signInAnonymously()
        } catch {
            guestError = error.localizedDescription
        }
    }
}

#Preview {
    AuthGateView()
}
