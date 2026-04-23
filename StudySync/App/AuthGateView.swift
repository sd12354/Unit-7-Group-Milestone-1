import SwiftUI

/// Auth gate — shows Login / Register when signed out, ContentView when signed in.
struct AuthGateView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                NavigationStack {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
        }
    }
}

#Preview {
    AuthGateView()
}
