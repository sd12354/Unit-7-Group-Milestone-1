import SwiftUI

/// Auth gate — shows Login / Register when signed out, ContentView when signed in.
struct AuthGateView: View {

    @StateObject private var authViewModel = AuthViewModel()
    @State private var showLaunchAnimation = true

    var body: some View {
        ZStack {
            Group {
                if authViewModel.isSignedIn {
                    ContentView()
                        .environmentObject(authViewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    NavigationStack {
                        LoginView()
                            .environmentObject(authViewModel)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            if showLaunchAnimation {
                AppLoadingView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeInOut(duration: 0.35)) {
                showLaunchAnimation = false
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isSignedIn)
    }
}

#Preview {
    AuthGateView()
}
