import Foundation
import FirebaseFirestore

/// Firestore-backed model for a study session.
/// Maps to the `sessions` collection defined in Issue 5.
struct StudySession: Identifiable, Codable {
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

    /// Computed — how many spots are left (nil means unlimited)
    var spotsRemaining: Int? {
        guard let max = maxAttendees else { return nil }
        return max - attendeeIds.count
    }

    var isFull: Bool {
        guard let spots = spotsRemaining else { return false }
        return spots <= 0
    }
}
