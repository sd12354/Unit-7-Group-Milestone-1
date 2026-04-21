import Foundation
import FirebaseFirestore

/// Firestore-backed model for a user profile.
/// Maps to the `users/{uid}` document defined in Issue 1.
struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?

    var displayName: String
    var bio: String
    var photoURL: String?
}
