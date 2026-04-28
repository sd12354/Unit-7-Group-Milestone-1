import SwiftUI
import FirebaseAuth

struct UserAvatarBadgeView: View {
    let user: User?
    var fallbackFillColor: Color = Color.white.opacity(0.95)
    var fallbackTextColor: Color = Color(hex: "2D3A65")

    var body: some View {
        Group {
            if let url = user?.photoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsBadge
                    }
                }
            } else {
                initialsBadge
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    private var initialsBadge: some View {
        Circle()
            .fill(fallbackFillColor)
            .overlay(
                Text(initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(fallbackTextColor)
            )
    }

    private var initials: String {
        let name = (user?.displayName ?? user?.email ?? "P").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "P" }
        let first = String(name.prefix(1)).uppercased()
        return first
    }
}
