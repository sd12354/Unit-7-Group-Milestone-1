import SwiftUI

/// Home — upcoming session feed (Milestone 2 — Issue 7).
struct HomeView: View {

    @State private var sessions: [StudySession] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && sessions.isEmpty {
                    ProgressView("Loading sessions…")
                } else if let loadError {
                    ContentUnavailableView(
                        "Could not refresh",
                        systemImage: "wifi.exclamationmark",
                        description: Text(loadError)
                    )
                    .refreshable { await loadSessions() }
                } else if sessions.isEmpty {
                    ContentUnavailableView(
                        "No upcoming sessions",
                        systemImage: "calendar.badge.clock",
                        description: Text("Pull down to refresh, or create one from the Create tab.")
                    )
                    .refreshable { await loadSessions() }
                } else {
                    List(sessions) { session in
                        if let id = session.id {
                            NavigationLink(value: id) {
                                SessionRowView(session: session)
                            }
                        }
                    }
                    .refreshable { await loadSessions() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Study Sessions")
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
        }
        .task { await loadSessions() }
    }

    @MainActor
    private func loadSessions() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            sessions = try await SessionRepository.getSessions()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct SessionRowView: View {
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
    HomeView()
}
