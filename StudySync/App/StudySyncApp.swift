import SwiftUI
import FirebaseCore

@main
struct StudySyncApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            AuthGateView()
        }
    }
}
