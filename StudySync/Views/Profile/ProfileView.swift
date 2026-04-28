import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var userProfile: UserProfile?
    @State private var profileLoadError: String?
    @State private var isEditingProfile = false
    @State private var isLoadingProfile = false
    @State private var hostedCount = 0
    @State private var joinedCount = 0
    @State private var scrollResetToken = UUID()
    @State private var pushReminders = true
    @State private var sessionUpdates = true
    private let sectionBackground = Color.white

    private var user: User? { authViewModel.currentUser }

    var body: some View {
        NavigationStack {
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {

                            profileHero
                                .padding(.top, 74)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 24)

                            VStack(spacing: 14) {
                                statsRow
                                    .padding(.top, 8)

                                VStack(spacing: 0) {
                                    notificationSettingsCard
                                        .padding(.bottom, 6)
                                }
                                .background(sectionBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                if let profileLoadError, !profileLoadError.isEmpty {
                                    Text(profileLoadError)
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.error)
                                }

                                Button(role: .destructive) {
                                    authViewModel.signOut()
                                } label: {
                                    Text("Log Out")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.error)
                                .appPressEffect()
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: max(proxy.size.height * 0.72, 520), alignment: .top)
                            .padding(12)
                            .background(Color.white.opacity(0.92))
                        }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    }
                    .id(scrollResetToken)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTransparentKeepsLayout()
            .sheet(isPresented: $isEditingProfile) {
                EditProfileSheet(userProfile: $userProfile, user: user)
            }
            .task(id: user?.uid) {
                await loadUserProfile()
                await loadSessionStats()
            }
            .onAppear {
                scrollResetToken = UUID()
            }
        }
    }

    private var profileHero: some View {
        VStack(spacing: 14) {
            profileImage
                .frame(width: 92, height: 92)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))

            Text(displayNameText)
                .font(AppTheme.sectionTitleFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(bioLine)
                .font(AppTheme.bodyFont)
                .foregroundStyle(Color.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Button {
                isEditingProfile = true
            } label: {
                HStack(spacing: 8) {
                    Text("Edit Profile")
                    Image(systemName: "square.and.pencil")
                }
                .font(AppTheme.bodyFont.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 9)
                .background(.white)
                .foregroundStyle(Color(hex: "2D3A65"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .appPressEffect()
        }
        .frame(maxWidth: .infinity)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 0) {
            statCell(value: "\(hostedCount)", title: "Sessions\nHosted")
            Divider().frame(height: 82)
            statCell(value: "\(joinedCount)", title: "Sessions\nJoined")
            Divider().frame(height: 82)
            statCell(value: memberSinceText, title: "Member\nSince")
        }
        .padding(.horizontal, 8)
    }

    private func statCell(value: String, title: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(hex: "2D3A65"))
            Text(title)
                .font(AppTheme.smallFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "2D3A65").opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private func actionRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.smallFont.weight(.semibold))
                .foregroundStyle(Color(hex: "2D3A65"))
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color(hex: "2D3A65").opacity(0.75))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }

    private var notificationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notifications", systemImage: "bell.fill")
                .font(AppTheme.smallFont.weight(.semibold))
                .foregroundStyle(Color(hex: "2D3A65"))

            Toggle("Push reminders", isOn: $pushReminders)
                .font(AppTheme.smallFont)
            Toggle("Session updates", isOn: $sessionUpdates)
                .font(AppTheme.smallFont)
        }
        .tint(AppTheme.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var memberSinceText: String {
        guard let date = user?.metadata.creationDate else { return "—" }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var initialsText: String {
        let source = displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let chars = source.prefix(2)
        return chars.isEmpty ? "P" : "\(chars)…"
    }

    private var header: some View {
        EmptyView()
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
        Circle()
            .fill(Color.black.opacity(0.12))
    }

    private var displayNameText: String {
        if let name = userProfile?.displayName, !name.isEmpty { return name }
        if let name = user?.displayName, !name.isEmpty { return name }
        return "Not set"
    }

    private var bioLine: String {
        let bio = userProfile?.bio ?? ""
        return bio.isEmpty ? "Add a short bio." : bio
    }

    private func loadUserProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
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

    private func loadSessionStats() async {
        do {
            async let hosting = SessionRepository.getHostingSessions()
            async let joined = SessionRepository.getJoinedSessions()
            hostedCount = try await hosting.count
            joinedCount = try await joined.count
        } catch {
            // Keep defaults on failure.
        }
    }
}

// MARK: - Edit Sheet

private struct EditProfileSheet: View {

    @Binding var userProfile: UserProfile?
    let user: User?
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName
        case bio
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Your name", text: $displayName)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .displayName)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .displayName ? AppTheme.accent : AppTheme.primary.opacity(0.45), lineWidth: focusedField == .displayName ? 2.5 : 1.5)
                        )
                        .listRowBackground(AppTheme.surface)
                }
                Section("Bio") {
                    TextEditor(text: $bio)
                        .focused($focusedField, equals: .bio)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .bio ? AppTheme.accent : AppTheme.primary.opacity(0.45), lineWidth: focusedField == .bio ? 2.5 : 1.5)
                        )
                        .listRowBackground(AppTheme.surface)
                }
                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button {
                            Task { await saveProfile() }
                        } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .onAppear {
                displayName = userProfile?.displayName ?? user?.displayName ?? ""
                bio = userProfile?.bio ?? ""
            }
        }
    }

    private func saveProfile() async {
        guard let uid = user?.uid else { return }
        isSaving = true
        saveError = nil

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(["displayName": displayName, "bio": bio], merge: true)

            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = displayName
            try await changeRequest?.commitChanges()

            if userProfile != nil {
                userProfile?.displayName = displayName
                userProfile?.bio = bio
            } else {
                userProfile = UserProfile(displayName: displayName, bio: bio, photoURL: nil)
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
