import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Firestore read/write for study sessions (`sessions` collection).
/// Milestone 2 — Issues 5 & 8.
enum SessionRepository {

    private static var db: Firestore { Firestore.firestore() }
    private static var sessions: CollectionReference { db.collection("sessions") }

    enum SessionError: LocalizedError {
        case notSignedIn
        case sessionNotFound
        case sessionFull
        case hostCannotJoinAsAttendee

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You must be signed in."
            case .sessionNotFound: return "That session could not be found."
            case .sessionFull: return "This session is full."
            case .hostCannotJoinAsAttendee: return "You are hosting this session."
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

        return try snapshot.documents.map { doc in
            try doc.data(as: StudySession.self)
        }
    }

    /// Upcoming sessions where the current user is the host.
    static func getHostingSessions() async throws -> [StudySession] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let snapshot = try await sessions
            .whereField("hostId", isEqualTo: uid)
            .whereField("startTime", isGreaterThan: Timestamp(date: Date()))
            .order(by: "startTime", descending: false)
            .getDocuments()

        return try snapshot.documents.map { doc in
            try doc.data(as: StudySession.self)
        }
    }

    /// Upcoming sessions where the current user appears in `attendeeIds`.
    static func getJoinedSessions() async throws -> [StudySession] {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw SessionError.notSignedIn
        }

        let snapshot = try await sessions
            .whereField("attendeeIds", arrayContains: uid)
            .whereField("startTime", isGreaterThan: Timestamp(date: Date()))
            .order(by: "startTime", descending: false)
            .getDocuments()

        return try snapshot.documents.map { doc in
            try doc.data(as: StudySession.self)
        }
    }

    static func getSessionById(_ id: String) async throws -> StudySession {
        let doc = try await sessions.document(id).getDocument()
        guard doc.exists else { throw SessionError.sessionNotFound }
        return try doc.data(as: StudySession.self)
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
            do {
                let session = try snapshot.data(as: StudySession.self)
                onUpdate(.success(session))
            } catch {
                onUpdate(.failure(error))
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
}
