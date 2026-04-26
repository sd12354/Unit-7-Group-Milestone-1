import SwiftUI
import FirebaseAuth

/// My Sessions — split into sessions the user hosts and sessions they joined.
struct MySessionsView: View {

    @State private var hostingSessions: [StudySession] = []
    @State private var joinedSessions: [StudySession] = []
    @State private var isLoading = false
    @State private var loadError: String?

    private var isSignedIn: Bool { Auth.auth().currentUser != nil }

    var body: some View {
        NavigationStack {
            Group {
                if !isSignedIn {
                    ContentUnavailableView(
                        "Sign in to view sessions",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Your hosted and joined sessions will appear here.")
                    )
                } else if isLoading && hostingSessions.isEmpty && joinedSessions.isEmpty {
                    ProgressView("Loading your sessions…")
                } else if let loadError {
                    ContentUnavailableView(
                        "Could not refresh",
                        systemImage: "wifi.exclamationmark",
                        description: Text(loadError)
                    )
                    .refreshable { await loadSessions() }
                } else {
                    List {
                        Section("Hosting") {
                            if hostingSessions.isEmpty {
                                Text("You are not hosting any upcoming sessions.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(hostingSessions) { session in
                                    if let id = session.id {
                                        NavigationLink(value: id) {
                                            MySessionRowView(session: session)
                                        }
                                    }
                                }
                            }
                        }

                        Section("Joined") {
                            if joinedSessions.isEmpty {
                                Text("You have not joined any upcoming sessions.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(joinedSessions) { session in
                                    if let id = session.id {
                                        NavigationLink(value: id) {
                                            MySessionRowView(session: session)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .refreshable { await loadSessions() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("My Sessions")
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
        }
        .task { await loadSessions() }
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

        do {
            async let hosting = SessionRepository.getHostingSessions()
            async let joined = SessionRepository.getJoinedSessions()
            hostingSessions = try await hosting
            joinedSessions = try await joined
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct MySessionRowView: View {
    let session: StudySession

    private static let rowDate: Date.FormatStyle =
        .dateTime
        .month(.abbreviated)
        .day()
        .hour()
        .minute()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.title)
                .font(.headline)

            Text(session.subjectTag)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label(session.startTime.formatted(Self.rowDate), systemImage: "clock")
                Spacer(minLength: 8)
                Label(session.locationText, systemImage: "mappin.and.ellipse")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Label("\(session.attendeeCount) joined", systemImage: "person.2")
                if let max = session.maxAttendees {
                    Text("· max \(max)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MySessionsView()
}
