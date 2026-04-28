import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import UIKit

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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var showLogoutConfirmation = false
    private let sectionBackground = Color.white

    private var user: User? { authViewModel.currentUser }

    var body: some View {
        NavigationStack {
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        profileHero
                            .padding(.top, 70)
                            .padding(.horizontal, 20)

                        statsRow
                            .padding(.horizontal, 20)

                        notificationSettingsCard
                            .padding(.horizontal, 20)

                        if let profileLoadError, !profileLoadError.isEmpty {
                            Text(profileLoadError)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.error)
                                .padding(.horizontal, 20)
                        }

                        logoutButton
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                    }
                }
                .id(scrollResetToken)
                .safeAreaPadding(.bottom, 88)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTransparentKeepsLayout()
            .sheet(isPresented: $isEditingProfile) {
                EditProfileSheet(userProfile: $userProfile, user: user)
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task { await processPickedPhoto(item) }
            }
            .task(id: user?.uid) {
                await loadUserProfile()
                await loadSessionStats()
            }
            .onAppear {
                scrollResetToken = UUID()
            }
            .alert("Log Out?", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to log out of StudySync?")
            }
        }
    }

    private var logoutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.error)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.error.opacity(0.45), lineWidth: 1.2)
                )
        }
        .buttonStyle(.plain)
        .appPressEffect()
    }

    private var profileHero: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                profileImage
                    .frame(width: 82, height: 82)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.85), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 7, y: 3)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Group {
                        if isUploadingPhoto {
                            ProgressView()
                                .tint(Color(hex: "2D3A65"))
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "2D3A65"))
                        }
                    }
                    .padding(7)
                    .background(Color.white.opacity(0.94))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.95), lineWidth: 1)
                    )
                    .offset(x: -2, y: -2)
                }
                .buttonStyle(.plain)
            }

            Text(displayNameText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(bioLine)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)

            Button {
                isEditingProfile = true
            } label: {
                Label("Edit Profile", systemImage: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "2D3A65"))
                    .padding(.horizontal, 20)
                    .frame(height: 39)
                    .background(Color.white.opacity(0.34))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .appPressEffect()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 18) {
            statCell(value: "\(hostedCount)", title: "Sessions\nHosted", icon: "person.crop.circle.badge.checkmark")
            statCell(value: "\(joinedCount)", title: "Sessions\nJoined", icon: "person.2.fill")
            statCell(value: memberSinceText, title: "Member\nSince", icon: "calendar.circle.fill")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 7)
    }

    private func statCell(value: String, title: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            Text(value)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AppTheme.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "6B7280").opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
        VStack(alignment: .leading, spacing: 10) {
            Label("Notifications", systemImage: "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "2D3A65"))

            notificationToggle(
                title: "Push reminders",
                subtitle: "Get a heads-up before upcoming sessions.",
                isOn: $pushReminders
            )
            Divider().overlay(Color(hex: "E8EEF7"))
            notificationToggle(
                title: "Session updates",
                subtitle: "Be notified about joins, edits, and changes.",
                isOn: $sessionUpdates
            )
        }
        .tint(AppTheme.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(sectionBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.primary.opacity(0.09), radius: 8, y: 4)
    }

    private func notificationToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "6B7280"))
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private var memberSinceText: String {
        guard let date = user?.metadata.creationDate else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "MMM ''yy"
        return formatter.string(from: date)
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
        if let urlString, urlString.hasPrefix("data:image"), let image = Self.imageFromDataURL(urlString) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let urlString, let url = URL(string: urlString) {
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

    private func processPickedPhoto(_ item: PhotosPickerItem) async {
        guard let uid = user?.uid else { return }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let resized = uiImage.resized(maxSide: 600),
                  let jpeg = resized.jpegData(compressionQuality: 0.72)
            else { return }

            let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(["photoURL": dataURL], merge: true)

            if userProfile != nil {
                userProfile?.photoURL = dataURL
            } else {
                userProfile = UserProfile(
                    displayName: user?.displayName ?? "Not set",
                    bio: "",
                    photoURL: dataURL
                )
            }
        } catch {
            profileLoadError = "Could not update profile photo."
        }
    }

    private static func imageFromDataURL(_ value: String) -> UIImage? {
        guard let commaIndex = value.firstIndex(of: ",") else { return nil }
        let base64 = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)
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

private extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage? {
        let largest = max(size.width, size.height)
        guard largest > maxSide else { return self }
        let scale = maxSide / largest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: target))
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
    private let bioLimit = 180

    private enum Field: Hashable {
        case displayName
        case bio
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F7FB")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "374151"))
                            TextField("Your name", text: $displayName)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .displayName)
                                .padding(.horizontal, 12)
                                .frame(height: 44)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "374151"))
                            ZStack(alignment: .bottomTrailing) {
                                TextEditor(text: $bio)
                                    .focused($focusedField, equals: .bio)
                                    .frame(minHeight: 86, maxHeight: 86)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .onChange(of: bio) { _, newValue in
                                        if newValue.count > bioLimit {
                                            bio = String(newValue.prefix(bioLimit))
                                        }
                                    }
                                Text("\(bio.count)/\(bioLimit)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color(hex: "6B7280"))
                                    .padding(.trailing, 10)
                                    .padding(.bottom, 8)
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)

                        if let saveError {
                            Text(saveError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    Task { await saveProfile() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Spacer()
                    }
                    .frame(height: 52)
                    .background(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving ? Color(hex: "A8AFBF") : AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color(hex: "F5F7FB").opacity(0.98))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                    .foregroundStyle(Color(hex: "6B7280"))
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .foregroundStyle(AppTheme.primary)
                    .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
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
