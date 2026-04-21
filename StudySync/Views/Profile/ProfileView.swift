import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Profile screen — account info from Firebase Auth plus `users/{uid}` from Firestore when present.
struct ProfileView: View {

    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var userProfile: UserProfile?
    @State private var profileLoadError: String?

    private var user: User? { authViewModel.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    Group {
                        sectionTitle("Account")
                        infoRow(title: "Email", value: user?.email ?? "—")
                        infoRow(title: "User ID", value: user?.uid ?? "—", mono: true)
                        if let phone = user?.phoneNumber, !phone.isEmpty {
                            infoRow(title: "Phone", value: phone)
                        }
                    }

                    Group {
                        sectionTitle("Profile")
                        infoRow(
                            title: "Display name",
                            value: displayNameText
                        )
                        infoRow(title: "Bio", value: bioLine)
                    }

                    if let profileLoadError, !profileLoadError.isEmpty {
                        Text(profileLoadError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(role: .destructive) {
                        authViewModel.signOut()
                    } label: {
                        Text("Log Out")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .task(id: user?.uid) {
                await loadUserProfile()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            profileImage
                .frame(width: 72, height: 72)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(displayNameText)
                    .font(.title3.weight(.semibold))
                Text(user?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        let urlString = userProfile?.photoURL ?? user?.photoURL?.absoluteString
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholderAvatar
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.secondary.opacity(0.6))
    }

    private var displayNameText: String {
        if let name = userProfile?.displayName, !name.isEmpty {
            return name
        }
        if let name = user?.displayName, !name.isEmpty {
            return name
        }
        return "Not set"
    }

    private var bioLine: String {
        let bio = userProfile?.bio ?? ""
        return bio.isEmpty ? "No bio yet." : bio
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func infoRow(title: String, value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(mono ? .caption.monospaced() : .body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func loadUserProfile() async {
        profileLoadError = nil
        userProfile = nil
        guard let uid = user?.uid else { return }

        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()

            if snapshot.exists {
                userProfile = try snapshot.data(as: UserProfile.self)
            }
        } catch {
            profileLoadError = error.localizedDescription
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
