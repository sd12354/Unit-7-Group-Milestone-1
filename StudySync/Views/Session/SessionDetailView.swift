import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Full session info, attendee list, join / leave (Milestone 2 — Issue 8).
struct SessionDetailView: View {

    let sessionId: String

    @State private var session: StudySession?
    @State private var loadError: String?
    @State private var actionError: String?
    @State private var joinLeaveInFlight = false

    @State private var listener: ListenerRegistration?

    private var currentUid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        Group {
            if let session {
                sessionContent(session)
            } else if loadError != nil {
                ContentUnavailableView(
                    "Could not load session",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError ?? "")
                )
            } else {
                ProgressView("Loading…")
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { attachListener() }
        .onDisappear { detachListener() }
        .alert("Something went wrong", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: StudySession) -> some View {
        List {
            Section {
                LabeledContent("Title", value: session.title)
                LabeledContent("Subject", value: session.subjectTag)
                LabeledContent("When", value: session.startTime.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Where", value: session.locationText)
            }

            Section("About") {
                Text(session.description.isEmpty ? "No description." : session.description)
                    .font(.body)
                    .foregroundStyle(session.description.isEmpty ? .secondary : .primary)
            }

            Section("Attendees (\(session.attendeeCount))") {
                if session.attendeeIds.isEmpty {
                    Text("No one has joined yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.attendeeIds, id: \.self) { uid in
                        Text(attendeeLabel(uid: uid))
                            .font(.subheadline)
                    }
                }
            }

            Section {
                joinLeaveSection(for: session)
            }
        }
    }

    @ViewBuilder
    private func joinLeaveSection(for session: StudySession) -> some View {
        let uid = currentUid
        let isHost = uid == session.hostId
        let isAttendee = uid.map { session.attendeeIds.contains($0) } ?? false

        if isHost {
            Text("You are hosting this session.")
                .foregroundStyle(.secondary)
        } else if isAttendee {
            Button(role: .destructive, action: { Task { await performLeave() } }) {
                if joinLeaveInFlight {
                    ProgressView()
                } else {
                    Text("Leave session")
                }
            }
            .disabled(joinLeaveInFlight || uid == nil)
        } else {
            let canJoin = !(session.isFull) && uid != nil
            Button(action: { Task { await performJoin() } }) {
                if joinLeaveInFlight {
                    ProgressView()
                } else {
                    Text("Join session")
                }
            }
            .disabled(!canJoin || joinLeaveInFlight)
            .buttonStyle(.borderedProminent)

            if session.isFull {
                Text("This session is full.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if uid == nil {
                Text("Sign in to join.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func attendeeLabel(uid: String) -> String {
        if uid == currentUid {
            return "You (\(shortId(uid)))"
        }
        return "Member \(shortId(uid))"
    }

    private func shortId(_ uid: String) -> String {
        String(uid.prefix(8))
    }

    private func attachListener() {
        detachListener()
        listener = SessionRepository.observeSession(id: sessionId) { result in
            Task { @MainActor in
                switch result {
                case .success(let s):
                    self.session = s
                    self.loadError = nil
                case .failure(let e):
                    self.loadError = e.localizedDescription
                }
            }
        }
    }

    private func detachListener() {
        listener?.remove()
        listener = nil
    }

    private func performJoin() async {
        joinLeaveInFlight = true
        defer { joinLeaveInFlight = false }
        do {
            try await SessionRepository.joinSession(sessionId: sessionId)
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func performLeave() async {
        joinLeaveInFlight = true
        defer { joinLeaveInFlight = false }
        do {
            try await SessionRepository.leaveSession(sessionId: sessionId)
        } catch {
            actionError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: "preview-id")
    }
}
