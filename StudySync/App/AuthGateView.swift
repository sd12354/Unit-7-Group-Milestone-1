import SwiftUI

/// Auth gate — shows LoginView when signed out, ContentView when signed in.
struct AuthGateView: View {

    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if authViewModel.isSignedIn {
                ContentView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    AuthGateView()
}
