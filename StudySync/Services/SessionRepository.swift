import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore read/write for study sessions (`sessions` collection).
/// Milestone 2 — Issues 5 & 8.
enum SessionRepository {

    private static var db: Firestore { Firestore.firestore() }
    private static var sessions: CollectionReference { db.collection("sessions") }
    struct SessionCancellationNotice: Identifiable {
        let id: String
        let message: String
    }

    enum SessionError: LocalizedError {
        case notSignedIn
        case sessionNotFound
        case sessionFull
        case hostCannotJoinAsAttendee
        case onlyHostCanCancel

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You must be signed in."
            case .sessionNotFound: return "That session could not be found."
            case .sessionFull: return "This session is full."
            case .hostCannotJoinAsAttendee: return "You are hosting this session."
            case .onlyHostCanCancel: return "Only the host can cancel this session."
            }
        }
    }

    // MARK: - Issue 5 — Create / read

    /// Creates a session document and returns its id.
    static func createSession(
        title: String,
        subjectTag: String,
        dateTime: Date,
        location: String,
        capacity: Int?,
        description: String
    ) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let session = StudySession(
            id: nil,
            title: title,
            subjectTag: subjectTag,
            startTime: dateTime,
            endTime: nil,
            locationText: location,
            description: description,
            maxAttendees: capacity,
            hostId: uid,
            attendeeIds: []
        )

        let ref = sessions.document()
        try ref.setData(from: session)
        return ref.documentID
    }

    /// Upcoming sessions with `startTime` after now, oldest first.
    static func getSessions() async throws -> [StudySession] {
        let snapshot = try await sessions
            .whereField("startTime", isGreaterThan: Timestamp(date: Date()))
            .order(by: "startTime", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap(sessionFromDocument)
    }

    /// Sessions where the current user is the host (created by them), newest first.
    /// Fetches without `order(by:)` so Firestore does not require a composite index; sorts in memory.
    static func getHostingSessions() async throws -> [StudySession] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let snapshot = try await sessions
            .whereField("hostId", isEqualTo: uid)
            .getDocuments()

        let list = snapshot.documents.compactMap(sessionFromDocument)
        return list.sorted { $0.startTime > $1.startTime }
    }

    /// Sessions where the current user appears in `attendeeIds`, newest first.
    /// Fetches without `order(by:)` so Firestore does not require a composite index; sorts in memory.
    static func getJoinedSessions() async throws -> [StudySession] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let snapshot = try await sessions
            .whereField("attendeeIds", arrayContains: uid)
            .getDocuments()

        let list = snapshot.documents.compactMap(sessionFromDocument)
        return list.sorted { $0.startTime > $1.startTime }
    }

    static func getSessionById(_ id: String) async throws -> StudySession {
        let doc = try await sessions.document(id).getDocument()
        guard doc.exists else { throw SessionError.sessionNotFound }
        guard let session = sessionFromSnapshot(doc) else { throw SessionError.sessionNotFound }
        return session
    }

    /// Live updates for a single session (join/leave from any client).
    static func observeSession(
        id: String,
        onUpdate: @escaping (Result<StudySession, Error>) -> Void
    ) -> ListenerRegistration {
        sessions.document(id).addSnapshotListener { snapshot, error in
            if let error {
                onUpdate(.failure(error))
                return
            }
            guard let snapshot, snapshot.exists else {
                onUpdate(.failure(SessionError.sessionNotFound))
                return
            }
            if let session = sessionFromSnapshot(snapshot) {
                onUpdate(.success(session))
            } else {
                onUpdate(.failure(SessionError.sessionNotFound))
            }
        }
    }

    // MARK: - Issue 8 — Join / leave

    /// Adds the current user to `attendeeIds` if capacity allows (transactional).
    static func joinSession(sessionId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let ref = sessions.document(sessionId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ transaction, errorPointer in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                guard snapshot.exists else {
                    errorPointer?.pointee = NSError(
                        domain: "StudySync",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: SessionError.sessionNotFound.localizedDescription]
                    )
                    return nil
                }

                let session: StudySession
                do {
                    session = try snapshot.data(as: StudySession.self)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                if session.hostId == uid {
                    errorPointer?.pointee = NSError(
                        domain: "StudySync",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: SessionError.hostCannotJoinAsAttendee.localizedDescription]
                    )
                    return nil
                }

                if session.attendeeIds.contains(uid) {
                    return nil
                }

                if session.isFull {
                    errorPointer?.pointee = NSError(
                        domain: "StudySync",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: SessionError.sessionFull.localizedDescription]
                    )
                    return nil
                }

                transaction.updateData(
                    ["attendeeIds": FieldValue.arrayUnion([uid])],
                    forDocument: ref
                )
                return nil
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Removes the current user from `attendeeIds`.
    static func leaveSession(sessionId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let ref = sessions.document(sessionId)
        try await ref.updateData([
            "attendeeIds": FieldValue.arrayRemove([uid])
        ])
    }

    static func updateSession(
        sessionId: String,
        title: String,
        subjectTag: String,
        dateTime: Date,
        location: String,
        capacity: Int?,
        description: String
    ) async throws {
        let ref = sessions.document(sessionId)
        try await ref.updateData([
            "title": title,
            "subjectTag": subjectTag,
            "startTime": Timestamp(date: dateTime),
            "locationText": location,
            "maxAttendees": capacity as Any,
            "description": description
        ])
    }

    static func cancelSession(
        sessionId: String,
        reason: String?
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let ref = sessions.document(sessionId)
        let snapshot = try await ref.getDocument()
        guard let session = sessionFromSnapshot(snapshot) else {
            throw SessionError.sessionNotFound
        }
        guard session.hostId == uid else {
            throw SessionError.onlyHostCanCancel
        }

        let trimmedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload: [String: Any] = [
            "cancelled": true,
            "cancellationReason": (trimmedReason?.isEmpty == false ? trimmedReason as Any : NSNull()),
            "cancelledAt": FieldValue.serverTimestamp()
        ]
        try await ref.updateData(payload)

        let attendeeIds = session.attendeeIds.filter { $0 != uid }
        if !attendeeIds.isEmpty {
            let batch = db.batch()
            for attendeeId in attendeeIds {
                let noticeRef = db.collection("users")
                    .document(attendeeId)
                    .collection("notifications")
                    .document()
                batch.setData([
                    "type": "session_cancelled",
                    "sessionId": sessionId,
                    "title": session.title,
                    "hostId": uid,
                    "reason": trimmedReason ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "read": false
                ], forDocument: noticeRef)
            }
            try await batch.commit()
        }
    }

    private static func sessionFromDocument(_ doc: QueryDocumentSnapshot) -> StudySession? {
        if let decoded = try? doc.data(as: StudySession.self) {
            return decoded
        }

        let data = doc.data()
        guard let hostId = data["hostId"] as? String else {
            return nil
        }
        let title = (data["title"] as? String) ?? "Untitled session"
        let subjectTag = (data["subjectTag"] as? String) ?? "General"
        let locationText = (data["locationText"] as? String) ?? "Location not provided"
        let description = (data["description"] as? String) ?? ""
        let maxAttendees = data["maxAttendees"] as? Int
        let attendeeIds = (data["attendeeIds"] as? [String]) ?? []
        let cancelled = data["cancelled"] as? Bool
        let cancellationReason = data["cancellationReason"] as? String

        let startTime: Date
        if let timestamp = data["startTime"] as? Timestamp {
            startTime = timestamp.dateValue()
        } else {
            startTime = Date.distantFuture
        }

        let endTime: Date?
        if let timestamp = data["endTime"] as? Timestamp {
            endTime = timestamp.dateValue()
        } else {
            endTime = nil
        }

        let cancelledAt: Date?
        if let timestamp = data["cancelledAt"] as? Timestamp {
            cancelledAt = timestamp.dateValue()
        } else {
            cancelledAt = nil
        }

        return StudySession(
            id: doc.documentID,
            title: title,
            subjectTag: subjectTag,
            startTime: startTime,
            endTime: endTime,
            locationText: locationText,
            description: description,
            maxAttendees: maxAttendees,
            hostId: hostId,
            attendeeIds: attendeeIds,
            cancelled: cancelled,
            cancellationReason: cancellationReason,
            cancelledAt: cancelledAt
        )
    }

    private static func sessionFromSnapshot(_ snapshot: DocumentSnapshot) -> StudySession? {
        if let decoded = try? snapshot.data(as: StudySession.self) {
            return decoded
        }
        guard let data = snapshot.data() else { return nil }
        guard let hostId = data["hostId"] as? String else { return nil }

        let title = (data["title"] as? String) ?? "Untitled session"
        let subjectTag = (data["subjectTag"] as? String) ?? "General"
        let locationText = (data["locationText"] as? String) ?? "Location not provided"
        let description = (data["description"] as? String) ?? ""
        let maxAttendees = data["maxAttendees"] as? Int
        let attendeeIds = (data["attendeeIds"] as? [String]) ?? []
        let cancelled = data["cancelled"] as? Bool
        let cancellationReason = data["cancellationReason"] as? String

        let startTime = (data["startTime"] as? Timestamp)?.dateValue() ?? Date.distantFuture
        let endTime = (data["endTime"] as? Timestamp)?.dateValue()
        let cancelledAt = (data["cancelledAt"] as? Timestamp)?.dateValue()

        return StudySession(
            id: snapshot.documentID,
            title: title,
            subjectTag: subjectTag,
            startTime: startTime,
            endTime: endTime,
            locationText: locationText,
            description: description,
            maxAttendees: maxAttendees,
            hostId: hostId,
            attendeeIds: attendeeIds,
            cancelled: cancelled,
            cancellationReason: cancellationReason,
            cancelledAt: cancelledAt
        )
    }

    static func consumeCancellationNotices() async throws -> [SessionCancellationNotice] {
        guard let uid = Auth.auth().currentUser?.uid else {
            return []
        }
        let noticesRef = db.collection("users").document(uid).collection("notifications")
        let snapshot = try await noticesRef
            .whereField("type", isEqualTo: "session_cancelled")
            .whereField("read", isEqualTo: false)
            .getDocuments()

        if snapshot.documents.isEmpty {
            return []
        }

        let notices: [SessionCancellationNotice] = snapshot.documents.map { doc in
            let data = doc.data()
            let title = (data["title"] as? String) ?? "A session"
            let reason = ((data["reason"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let message = reason.isEmpty
                ? "\(title) was cancelled by the host."
                : "\(title) was cancelled: \(reason)"
            return SessionCancellationNotice(id: doc.documentID, message: message)
        }

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.updateData(["read": true], forDocument: doc.reference)
        }
        try await batch.commit()
        return notices
    }
}
