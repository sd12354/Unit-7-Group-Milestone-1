import Foundation
import FirebaseFirestore

/// Firestore-backed model for a study session.
/// Maps to the `sessions` collection (Milestone 2 — Issue 5).
/// Fields align with spec: title, subject, dateTime (`startTime`), location, capacity (`maxAttendees`),
/// attendees (`attendeeIds`), hostId, description.
struct StudySession: Identifiable, Codable, Equatable {
    @DocumentID var id: String?

    var title: String
    var subjectTag: String
    var startTime: Date
    var endTime: Date?
    var locationText: String
    var description: String
    var maxAttendees: Int?
    var hostId: String
    var attendeeIds: [String]

    init(
        id: String? = nil,
        title: String,
        subjectTag: String,
        startTime: Date,
        endTime: Date? = nil,
        locationText: String,
        description: String,
        maxAttendees: Int?,
        hostId: String,
        attendeeIds: [String] = []
    ) {
        _id = DocumentID(wrappedValue: id)
        self.title = title
        self.subjectTag = subjectTag
        self.startTime = startTime
        self.endTime = endTime
        self.locationText = locationText
        self.description = description
        self.maxAttendees = maxAttendees
        self.hostId = hostId
        self.attendeeIds = attendeeIds
    }

    /// Spots left for attendees (host excluded). `nil` max means unlimited.
    var spotsRemaining: Int? {
        guard let max = maxAttendees else { return nil }
        return max - attendeeIds.count
    }

    var isFull: Bool {
        guard let spots = spotsRemaining else { return false }
        return spots <= 0
    }

    var attendeeCount: Int {
        attendeeIds.count
    }
}
