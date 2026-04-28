import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

/// Home — upcoming session feed (Milestone 2 — Issue 7).
struct HomeView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var sessions: [StudySession] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedFilter = "All"
    @State private var showCreateSheet = false
    @State private var editingSession: StudySession?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var navigationPath = NavigationPath()
    @State private var hostProfiles: [String: HostProfile] = [:]
    private let feedBottomClearance: CGFloat = 220

    private let filters = [
        "All",
        "Today",
        "This Week",
        "Past",
        "Math",
        "Computer Science",
        "Biology",
        "Chemistry",
        "Physics",
        "Statistics",
        "Data Science",
        "Engineering",
        "Psychology",
        "Sociology",
        "Political Science",
        "Philosophy",
        "Art",
        "Music",
        "Business",
        "Accounting",
        "Finance",
        "Marketing",
        "Nursing",
        "Pre-Med",
        "History",
        "English",
        "Economics"
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    VStack(spacing: 10) {
                        Label {
                            Text("\(greetingText), \(homeDisplayName)")
                        } icon: {
                            Image(systemName: greetingIconName)
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 14)
                        .padding(.top, 152)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.white.opacity(0.92))
                            TextField(
                                "",
                                text: $searchText,
                                prompt: Text("Search sessions")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.72))
                            )
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(.white)
                                .focused($isSearchFocused)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(isSearchFocused ? 0.55 : 0.35), lineWidth: isSearchFocused ? 2 : 1)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ScrollViewReader { tabProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(filters, id: \.self) { filter in
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.22)) {
                                                selectedFilter = filter
                                                tabProxy.scrollTo(filter, anchor: .center)
                                            }
                                        } label: {
                                            Text(filter)
                                                .font(.system(size: 14, weight: .semibold))
                                                .padding(.horizontal, 16)
                                                .frame(height: 36)
                                                .background(selectedFilter == filter ? AppTheme.surface : Color.clear)
                                                .foregroundStyle(selectedFilter == filter ? AppTheme.textPrimary : Color.white.opacity(0.94))
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .stroke(selectedFilter == filter ? Color.clear : Color.white.opacity(0.45), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .id(filter)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .frame(height: 52)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 12)

                        if isLoading && sessions.isEmpty {
                            List(0..<4, id: \.self) { _ in
                                LoadingSkeletonRow()
                                    .listRowBackground(Color.clear)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: feedBottomClearance)
                            }
                        } else if let loadError {
                            ContentUnavailableView("Could not refresh", systemImage: "wifi.exclamationmark", description: Text(loadError))
                                .foregroundStyle(.white)
                        } else if filteredSessions.isEmpty {
                            ContentUnavailableView("No sessions", systemImage: "calendar.badge.clock", description: Text("Try another filter or create a new session."))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .offset(y: -46)
                                .safeAreaPadding(.bottom, feedBottomClearance)
                        } else {
                            List(filteredSessions) { session in
                                if let id = session.id {
                                    Button {
                                        let isPastSession = session.startTime < Date()
                                        if session.hostId == authViewModel.currentUser?.uid && !isPastSession {
                                            editingSession = session
                                        } else {
                                            navigationPath.append(id)
                                        }
                                    } label: {
                                        SessionRowView(
                                            session: session,
                                            isOwnedByCurrentUser: session.hostId == authViewModel.currentUser?.uid,
                                            hostDisplayName: hostProfiles[session.hostId]?.displayName ?? "Host",
                                            hostPhotoURL: hostProfiles[session.hostId]?.photoURL,
                                            isJoinedByCurrentUser: session.attendeeIds.contains(authViewModel.currentUser?.uid ?? ""),
                                            isPastSession: session.startTime < Date()
                                        )
                                    }
                                    .buttonStyle(SessionCardButtonStyle())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .listSectionSeparator(.hidden)
                            .safeAreaInset(edge: .bottom) {
                                Color.clear.frame(height: feedBottomClearance)
                            }
                        }
                    }
                }
                .overlay(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Image("StudySyncLogoTransparent")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.trailing, -10)
                        Text("tudySync")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.bottom, -10)
                    }
                    .padding(.top, 78)
                }
            }
            .refreshable { await loadSessions() }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Circle()
                        .fill(Color(hex: "1F2F66"))
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(AppTheme.surface))
                        .shadow(color: Color(hex: "1F2F66").opacity(0.42), radius: 14, y: 8)
                        .shadow(color: Color(hex: "4B7BFF").opacity(0.22), radius: 22, y: 0)
                }
                .buttonStyle(.plain)
                .appPressEffect()
                .padding(.trailing, 18)
                // Keep FAB above the custom tab bar capsule.
                .padding(.bottom, 126)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(AppTheme.textPrimary)
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
        }
        .task { await loadSessions() }
        .sheet(isPresented: $showCreateSheet) {
            CreateView()
                .environmentObject(authViewModel)
        }
        .sheet(item: $editingSession) { session in
            CreateView(editingSession: session)
                .environmentObject(authViewModel)
        }
    }

    private var filteredSessions: [StudySession] {
        let now = Date()
        let base: [StudySession]
        switch selectedFilter {
        case "All":
            base = sessions.filter { $0.startTime >= now }
        case "Today":
            base = sessions.filter { Calendar.current.isDateInToday($0.startTime) }
        case "This Week":
            let calendar = Calendar.current
            guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return sessions }
            base = sessions.filter { week.contains($0.startTime) }
        case "Past":
            base = sessions
                .filter { $0.startTime < now }
                .sorted { $0.startTime > $1.startTime }
        default:
            base = sessions.filter { $0.subjectTag.localizedCaseInsensitiveContains(selectedFilter) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let active = base.filter { !$0.isCancelled }
        guard !query.isEmpty else { return active }
        return active.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subjectTag.localizedCaseInsensitiveContains(query) ||
            $0.locationText.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    private func loadSessions() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            sessions = try await SessionRepository.getSessions()
            await loadHostNamesIfNeeded(for: sessions)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadHostNamesIfNeeded(for sessions: [StudySession]) async {
        let currentUid = authViewModel.currentUser?.uid
        let ids = Set(
            sessions
                .map(\.hostId)
                .filter { !$0.isEmpty && $0 != currentUid && hostProfiles[$0] == nil }
        )
        guard !ids.isEmpty else { return }

        var fetched: [String: HostProfile] = [:]
        for id in ids {
            do {
                let doc = try await Firestore.firestore().collection("users").document(id).getDocument()
                let data = doc.data() ?? [:]
                let displayName = (data["displayName"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let photoURL = (data["photoURL"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                fetched[id] = HostProfile(
                    displayName: (displayName?.isEmpty == false) ? displayName! : "Host",
                    photoURL: (photoURL?.isEmpty == false) ? photoURL : nil
                )
            } catch {
                fetched[id] = HostProfile(displayName: "Host", photoURL: nil)
            }
        }
        hostProfiles.merge(fetched) { _, new in new }
    }

    private var homeDisplayName: String {
        if let name = authViewModel.currentUser?.displayName, !name.isEmpty { return name }
        if let email = authViewModel.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first?.capitalized ?? "Friend"
        }
        return "Friend"
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good night"
        }
    }

    private var greetingIconName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "sunrise.fill"
        case 12..<17:
            return "sun.max.fill"
        default:
            return "moon.stars.fill"
        }
    }
}

private struct SessionRowView: View {
    let session: StudySession
    let isOwnedByCurrentUser: Bool
    let hostDisplayName: String
    let hostPhotoURL: String?
    let isJoinedByCurrentUser: Bool
    let isPastSession: Bool

    private static let rowDate: Date.FormatStyle =
        .dateTime
        .month(.abbreviated)
        .day()
        .hour()
        .minute()

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(subjectAccent)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 10) {
                    Text(session.title)
                        .font(.system(size: 23, weight: .bold))
                        .lineLimit(2)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    if isPastSession {
                        Text("Past")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "6B7280"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "E5E7EB"))
                            .clipShape(Capsule())
                    }
                    Text(session.subjectTag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(subjectAccent.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(subjectAccent.opacity(0.18))
                        .clipShape(Capsule())
                }

                HStack(spacing: 9) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(subjectAccent.opacity(0.95))
                    Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("at")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                    Text(session.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                HStack(spacing: 9) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(subjectAccent.opacity(0.9))
                    Text(session.locationText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                        .padding(6)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                        )
                        .accessibilityHidden(true)
                }

                HStack {
                    hostAvatar
                    Text(isOwnedByCurrentUser ? "Host" : hostDisplayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(spotsText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(spotsBadgeForeground)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(spotsBadgeBackground)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(subjectAccent.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppTheme.primary.opacity(0.14), radius: 12, y: 6)
        .opacity(isPastSession ? 0.78 : 1)
        .saturation(isPastSession ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var spotsText: String {
        if isJoinedByCurrentUser {
            return "Joined"
        }
        if let spots = session.spotsRemaining {
            return spots <= 0 ? "Full" : "\(spots) spots left"
        }
        return "Open"
    }

    @ViewBuilder
    private var hostAvatar: some View {
        if isOwnedByCurrentUser {
            Circle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 20, height: 20)
        } else if let hostPhotoURL, hostPhotoURL.hasPrefix("data:image"), let image = imageFromDataURL(hostPhotoURL) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 20, height: 20)
                .clipShape(Circle())
        } else if let hostPhotoURL, let url = URL(string: hostPhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Circle().fill(Color.black.opacity(0.14))
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 20, height: 20)
        }
    }

    private func imageFromDataURL(_ value: String) -> UIImage? {
        guard let commaIndex = value.firstIndex(of: ",") else { return nil }
        let base64 = String(value[value.index(after: commaIndex)...])
        guard let data = Data(base64Encoded: base64, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)
    }

    private var subjectAccent: Color {
        let subject = session.subjectTag.lowercased()
        if subject.contains("math") || subject.contains("stat") { return Color(hex: "3B82F6") }
        if subject.contains("computer") || subject.contains("data") || subject.contains("engineering") { return Color(hex: "06B6D4") }
        if subject.contains("biology") || subject.contains("nursing") || subject.contains("pre-med") { return Color(hex: "10B981") }
        if subject.contains("chem") { return Color(hex: "8B5CF6") }
        if subject.contains("physics") { return Color(hex: "F59E0B") }
        return AppTheme.primary
    }

    private var spotsBadgeBackground: Color {
        if isJoinedByCurrentUser {
            return Color(hex: "D1FAE5")
        }
        if let spots = session.spotsRemaining {
            switch spots {
            case 4...:
                return Color(hex: "DCFCE7")
            case 2...3:
                return Color(hex: "FEF3C7")
            default:
                return Color(hex: "FEE2E2")
            }
        }
        return Color(hex: "DBEAFE")
    }

    private var spotsBadgeForeground: Color {
        if isJoinedByCurrentUser {
            return Color(hex: "047857")
        }
        if let spots = session.spotsRemaining {
            switch spots {
            case 4...:
                return Color(hex: "166534")
            case 2...3:
                return Color(hex: "92400E")
            default:
                return Color(hex: "B91C1C")
            }
        }
        return Color(hex: "1E40AF")
    }
}

private struct SessionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.93 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct HostProfile {
    let displayName: String
    let photoURL: String?
}

#Preview {
    HomeView()
}
