import SwiftUI

/// Create screen — form for posting a new study session.
/// TODO (Issue 6): Replace stub with a Form containing fields for title,
/// subject tag, date/time picker, location, max attendees, and description.
/// On submit, call SessionRepository.createSession() and navigate to the new session's detail.
struct CreateView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Create")
                    .font(.title2.weight(.semibold))

                Text("Post a new study session here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("New Session")
        }
    }
}

#Preview {
    CreateView()
}
