import Foundation
import FirebaseAuth

enum AuthEmailErrorMapper {

    /// Maps Firebase Auth errors to short, user-facing copy.
    static func message(for error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == AuthErrors.domain,
              let code = AuthErrorCode(rawValue: ns.code) else {
            return error.localizedDescription
        }

        switch code {
        case .invalidEmail:
            return "That email doesn’t look valid. Check for typos."
        case .wrongPassword:
            return "Wrong password. Try again or use Forgot password."
        case .userNotFound:
            return "No account exists for this email. Create one first."
        case .emailAlreadyInUse:
            return "That email is already in use. Sign in or use a different email."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .userDisabled:
            return "This account has been disabled."
        case .invalidCredential:
            return "Email or password is incorrect."
        case .tooManyRequests:
            return "Too many attempts. Wait a moment and try again."
        case .networkError:
            return "Network problem. Check your connection and try again."
        case .operationNotAllowed:
            return "Email/password sign-in isn’t enabled for this app in Firebase."
        case .requiresRecentLogin:
            return "Please sign in again to continue."
        default:
            return error.localizedDescription
        }
    }
}
