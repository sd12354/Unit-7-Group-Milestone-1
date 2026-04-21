import SwiftUI

/// Root view — hosts the 4-tab bottom navigation bar.
/// Each tab is a stub that will be filled in by its respective issue.
struct ContentView: View {

    var body: some View {
        TabView {

            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            CreateView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }

            MySessionsView()
                .tabItem {
                    Label("My Sessions", systemImage: "calendar")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    ContentView()
}
