import SwiftUI

/// Home screen — upcoming session feed.
/// TODO (Issue 7): Replace stub with a List/ScrollView that fetches upcoming
/// sessions from Firestore ordered by startTime, with pull-to-refresh.
struct HomeView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Home")
                    .font(.title2.weight(.semibold))

                Text("Upcoming sessions will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Study Sessions")
        }
    }
}

#Preview {
    HomeView()
}
