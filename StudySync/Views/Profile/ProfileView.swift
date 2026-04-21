import SwiftUI

/// Profile screen — current user's display name, bio, and photo.
/// TODO (Issue 4): Load user document from Firestore (users/{uid}),
/// display name/bio/photo, and wire Edit and Log Out buttons.
struct ProfileView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "person.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Profile")
                    .font(.title2.weight(.semibold))

                Text("Your name, bio, and photo will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("Sign out", role: .destructive) {
                    authViewModel.signOut()
                }
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
