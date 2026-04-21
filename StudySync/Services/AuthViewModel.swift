import Foundation
import FirebaseAuth
import Combine

/// Observes Firebase Auth state and exposes it to SwiftUI views.
/// TODO (Issue 2): Use this in AuthGateView to conditionally show
/// LoginView vs ContentView based on whether a user is signed in.
@MainActor
class AuthViewModel: ObservableObject {

    @Published var currentUser: User?
    @Published var isSignedIn: Bool = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isSignedIn = user != nil
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}
