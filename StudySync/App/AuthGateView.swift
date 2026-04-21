import SwiftUI

/// Auth gate — shows LoginView when signed out, ContentView when signed in.
/// TODO (Issue 2): Uncomment in StudySyncApp.swift once LoginView is built.
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

/// Temporary stand-in so the project compiles before Issue 2 is implemented.
private struct PlaceholderLoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("StudySync")
                .font(.largeTitle.weight(.bold))

            Text("Login screen coming in Issue 2.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AuthGateView()
}
