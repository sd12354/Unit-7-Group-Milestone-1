import SwiftUI
import FirebaseCore

@main
struct StudySyncApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            // TODO (Issue 2): Replace with AuthGateView that shows LoginView
            // when no user is signed in, and ContentView when signed in.
            ContentView()
        }
    }
}
