import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import MapKit

/// Full session info, attendee list, join / leave (Milestone 2 — Issue 8).
struct SessionDetailView: View {

    let sessionId: String

    @State private var session: StudySession?
    @State private var loadError: String?
    @State private var actionError: String?
    @State private var joinLeaveInFlight = false
    @State private var showCancelPrompt = false
    @State private var cancelReason = ""
    @State private var showEditSheet = false

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
                ProgressView("Loading session…")
                    .tint(AppTheme.primary)
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let session, currentUid == session.hostId, !session.isCancelled {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Session", systemImage: "square.and.pencil")
                    }
                }
            }
        }
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
        .alert("Cancel Session", isPresented: $showCancelPrompt) {
            TextField("Reason (optional)", text: $cancelReason)
            Button("Keep Session", role: .cancel) {}
            Button("Cancel Session", role: .destructive) {
                Task { await performCancel() }
            }
        } message: {
            Text("Attendees will be notified that this session was cancelled.")
        }
        .sheet(isPresented: $showEditSheet) {
            if let session {
                CreateView(editingSession: session)
            }
        }
    }

    @ViewBuilder
    private func sessionContent(_ session: StudySession) -> some View {
        List {
            Section {
                LabeledContent("Title", value: fallback(session.title, empty: "Untitled session"))
                LabeledContent("Subject", value: fallback(session.subjectTag, empty: "Not set"))
                LabeledContent("When", value: session.startTime.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Where", value: fallback(session.locationText, empty: "Not provided"))
            }

            Section("About") {
                Text(fallback(session.description, empty: "No description."))
                    .font(.body)
                    .foregroundStyle(session.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
            }

            if session.isCancelled {
                Section {
                    Label("This session has been cancelled.", systemImage: "xmark.octagon.fill")
                        .foregroundStyle(AppTheme.error)
                    if let reason = session.cancellationReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Reason: \(reason)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !session.locationText.trimmingCharacters(in: .whitespaces).isEmpty {
                Section {
                    Button {
                        openInMaps(address: session.locationText)
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                    }
                }
            }

            Section("Attendees (\(session.attendeeCount))") {
                if session.attendeeIds.isEmpty {
                    Text("No one has joined yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.attendeeIds, id: \.self) { uid in
                        Text(attendeeLabel(uid: uid))
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }

            Section {
                joinLeaveSection(for: session)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
    }

    @ViewBuilder
    private func joinLeaveSection(for session: StudySession) -> some View {
        let uid = currentUid
        let isHost = uid == session.hostId
        let isAttendee = uid.map { session.attendeeIds.contains($0) } ?? false

        if isHost {
            VStack(alignment: .leading, spacing: 10) {
                Text("You are hosting this session.")
                    .foregroundStyle(AppTheme.textSecondary)
                if !session.isCancelled {
                    Button(role: .destructive) {
                        showCancelPrompt = true
                    } label: {
                        if joinLeaveInFlight {
                            ProgressView()
                        } else {
                            Label("Cancel Session", systemImage: "xmark.octagon")
                        }
                    }
                    .tint(AppTheme.error)
                    .appPressEffect()
                    .disabled(joinLeaveInFlight)
                }
            }
        } else if session.isCancelled {
            Text("This session was cancelled by the host.")
                .foregroundStyle(AppTheme.error)
        } else if isAttendee {
            Button(role: .destructive, action: { Task { await performLeave() } }) {
                if joinLeaveInFlight {
                    ProgressView()
                } else {
                    Text("Leave session")
                }
            }
            .tint(AppTheme.error)
            .appPressEffect()
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
            .tint(AppTheme.primary)
            .appPressEffect()

            if session.isFull {
                Text("This session is full.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else if uid == nil {
                Text("Sign in to join.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
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

    private func fallback(_ text: String, empty replacement: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? replacement : trimmed
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

    private func performCancel() async {
        guard let session else { return }
        joinLeaveInFlight = true
        defer { joinLeaveInFlight = false }
        do {
            try await SessionRepository.cancelSession(
                sessionId: session.id ?? sessionId,
                reason: cancelReason
            )
            cancelReason = ""
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func openInMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: "preview-id")
    }
}
