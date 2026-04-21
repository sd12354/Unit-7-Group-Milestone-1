import SwiftUI

/// My Sessions screen — sessions the current user is hosting or has joined.
/// TODO (Issue 9): Replace stub with two sections ("Hosting" and "Joined"),
/// each backed by Firestore queries filtered on the current user.
struct MySessionsView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("My Sessions")
                    .font(.title2.weight(.semibold))

                Text("Sessions you host or have joined will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("My Sessions")
        }
    }
}

#Preview {
    MySessionsView()
}
