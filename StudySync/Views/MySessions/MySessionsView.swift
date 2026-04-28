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
    @State private var cancellationAlerts: [SessionRepository.SessionCancellationNotice] = []

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
        .alert(
            "Session update",
            isPresented: Binding(
                get: { !cancellationAlerts.isEmpty },
                set: { if !$0, !cancellationAlerts.isEmpty { cancellationAlerts.removeFirst() } }
            )
        ) {
            Button("OK") { if !cancellationAlerts.isEmpty { cancellationAlerts.removeFirst() } }
        } message: {
            Text(cancellationAlerts.first?.message ?? "")
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

        do {
            cancellationAlerts = try await SessionRepository.consumeCancellationNotices()
        } catch {
            // Non-blocking: session lists should still render even if alerts fail.
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(session.title)
                    .font(AppTheme.labelFont)
                    .lineLimit(2)
                Spacer()
                if session.isCancelled {
                    Text("Cancelled")
                        .font(AppTheme.smallFont)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.error.opacity(0.18))
                        .foregroundStyle(AppTheme.error)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if isHosting {
                    Text("Host")
                        .font(AppTheme.smallFont)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary)
                        .foregroundStyle(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Text(session.subjectTag)
                    .font(AppTheme.smallFont)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.tertiaryAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Label(session.startTime.formatted(Self.rowDate), systemImage: "calendar")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
            Label(session.locationText, systemImage: "mappin.and.ellipse")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)

            Text(attendeesText)
                .font(AppTheme.smallFont)
                .foregroundStyle(AppTheme.textSecondary)
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
            }
        }
        .padding(16)
        .foregroundStyle(AppTheme.textPrimary)
        .appCardSurface()
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var attendeesText: String {
        if let max = session.maxAttendees {
            return "\(session.attendeeCount) / \(max) attendees"
        }
        return "\(session.attendeeCount) attendees"
    }
}

#Preview {
    MySessionsView()
}
