import SwiftUI
import FirebaseAuth

/// My Sessions — split into sessions the user hosts and sessions they joined.
struct MySessionsView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var hostingSessions: [StudySession] = []
    @State private var joinedSessions: [StudySession] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedTab = "Hosting"
    @State private var navigationPath = NavigationPath()
    @State private var cancellationAlertMessage: String?
    @State private var shownCancelledSessionIDs: Set<String> = []

    private var isSignedIn: Bool { Auth.auth().currentUser != nil }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    HStack(spacing: 8) {
                        sessionTypeButton(
                            title: "Hosting",
                            icon: "person.crop.circle.badge.plus",
                            isSelected: selectedTab == "Hosting"
                        ) {
                            selectedTab = "Hosting"
                        }

                        sessionTypeButton(
                            title: "Joined",
                            icon: "person.2.fill",
                            isSelected: selectedTab == "Joined"
                        ) {
                            selectedTab = "Joined"
                        }
                    }
                    .padding(6)
                    .background(AppTheme.primary.opacity(0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    if !isSignedIn {
                        ContentUnavailableView(
                            "Sign in to view sessions",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text("Your hosted and joined sessions will appear here.")
                        )
                        .foregroundStyle(.white)
                    } else if isLoading && hostingSessions.isEmpty && joinedSessions.isEmpty {
                        List(0..<4, id: \.self) { _ in
                            LoadingSkeletonRow()
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    } else if let loadError {
                        ContentUnavailableView(
                            "Could not refresh",
                            systemImage: "wifi.exclamationmark",
                            description: Text(loadError)
                        )
                        .foregroundStyle(.white)
                        .refreshable { await loadSessions() }
                    } else if hostingSessions.isEmpty && joinedSessions.isEmpty {
                        ContentUnavailableView(
                            "No sessions yet",
                            systemImage: "calendar.badge.clock",
                            description: Text("Hosted, joined, and created sessions will appear here.")
                        )
                        .foregroundStyle(.white)
                        .refreshable { await loadSessions() }
                    } else {
                        List(displayedSessions) { session in
                            if let id = session.id {
                                Button {
                                    navigationPath.append(id)
                                } label: {
                                    MySessionRowView(session: session, isHosting: selectedTab == "Hosting")
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await loadSessions() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaPadding(.top, 68)
                .safeAreaPadding(.bottom, 84)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("My Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTransparentKeepsLayout()
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
        }
        .task { await loadSessions() }
        .onReceive(NotificationCenter.default.publisher(for: .sessionMembershipDidChange)) { _ in
            Task { await loadSessions() }
        }
        .alert("Session update", isPresented: Binding(
            get: { cancellationAlertMessage != nil },
            set: { if !$0 { cancellationAlertMessage = nil } }
        )) {
            Button("OK") { cancellationAlertMessage = nil }
        } message: {
            Text(cancellationAlertMessage ?? "")
        }
    }

    private var displayedSessions: [StudySession] {
        selectedTab == "Hosting" ? hostingSessions : joinedSessions
    }

    private func sessionTypeButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(isSelected ? AppTheme.textPrimary : Color.white.opacity(0.95))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isSelected ? AppTheme.surface : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func loadSessions() async {
        guard isSignedIn else {
            hostingSessions = []
            joinedSessions = []
            loadError = nil
            isLoading = false
            return
        }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        async let hostingTask = SessionRepository.getHostingSessions()
        async let joinedTask = SessionRepository.getJoinedSessions()

        var errors: [String] = []

        do {
            hostingSessions = try await hostingTask
        } catch {
            hostingSessions = []
            errors.append("Hosting: \(error.localizedDescription)")
        }

        do {
            joinedSessions = try await joinedTask
        } catch {
            joinedSessions = []
            errors.append("Joined: \(error.localizedDescription)")
        }

        loadError = errors.isEmpty ? nil : errors.joined(separator: "\n")

        if let cancelledJoinedSession = joinedSessions.first(where: { session in
            guard session.isCancelled, let id = session.id else { return false }
            return !shownCancelledSessionIDs.contains(id)
        }), let id = cancelledJoinedSession.id {
            shownCancelledSessionIDs.insert(id)
            let reason = (cancelledJoinedSession.cancellationReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            cancellationAlertMessage = reason.isEmpty
                ? "\(cancelledJoinedSession.title) was cancelled by the host."
                : "\(cancelledJoinedSession.title) was cancelled: \(reason)"
        }
    }
}

private struct MySessionRowView: View {
    let session: StudySession
    let isHosting: Bool

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

            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 10) {
                    Text(session.title)
                        .font(.system(size: 29, weight: .bold))
                        .lineLimit(2)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer(minLength: 8)
                    if session.isCancelled {
                        Text("Cancelled")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "FEE2E2"))
                            .foregroundStyle(Color(hex: "B91C1C"))
                            .clipShape(Capsule())
                    }
                    if isHosting {
                        Text("Host")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "DBEAFE"))
                            .foregroundStyle(Color(hex: "1E40AF"))
                            .clipShape(Capsule())
                    }
                    Text(session.subjectTag)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(subjectAccent.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(subjectAccent.opacity(0.18))
                        .clipShape(Capsule())
                }

                HStack(spacing: 9) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(subjectAccent.opacity(0.95))
                    Text(session.startTime.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("at")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                    Text(session.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                HStack(spacing: 9) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(subjectAccent.opacity(0.9))
                    Text(session.locationText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                        .padding(7)
                        .background(AppTheme.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.primary.opacity(0.2), lineWidth: 1))
                        .accessibilityHidden(true)
                }

                HStack {
                    Text(attendeesText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(spotsBadgeForeground)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(spotsBadgeBackground)
                        .clipShape(Capsule())
                    Spacer()
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
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var attendeesText: String {
        if let max = session.maxAttendees {
            return "\(session.attendeeCount) / \(max) attendees"
        }
        return "\(session.attendeeCount) attendees"
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
        if let max = session.maxAttendees {
            let spots = max - session.attendeeCount
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
        if let max = session.maxAttendees {
            let spots = max - session.attendeeCount
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

#Preview {
    MySessionsView()
}
