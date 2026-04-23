import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Observes Firebase Auth state and exposes auth actions to SwiftUI views.
@MainActor
class AuthViewModel: ObservableObject {

    @Published var currentUser: User?
    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Short success line (e.g. password reset email sent). Cleared with `clearError()`.
    @Published var transientNotice: String?

    @Published var phoneNumber: String = ""
    @Published var phoneVerificationCode: String = ""
    @Published var isPhoneCodeSent: Bool = false

    private var verificationID: String?
    /// Retained while Firebase Phone Auth presents reCAPTCHA UI.
    private var phoneAuthUIHelper: PhoneAuthUIHelper?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isSignedIn = user != nil
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func clearError() {
        errorMessage = nil
        transientNotice = nil
    }

    func signInWithEmail(email: String, password: String) async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = AuthEmailErrorMapper.message(for: error)
        }
    }

    /// Register with display name, then update Auth profile and create `users/{uid}` in Firestore.
    func registerWithEmail(displayName: String, email: String, password: String) async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = displayName
            try await change.commitChanges()

            let uid = result.user.uid
            try await Firestore.firestore().collection("users").document(uid).setData(
                [
                    "displayName": displayName,
                    "bio": "",
                ],
                merge: true
            )
            errorMessage = nil
        } catch {
            errorMessage = AuthEmailErrorMapper.message(for: error)
        }
    }

    func sendPasswordReset(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your email above, then tap Forgot password again."
            return
        }

        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        transientNotice = nil
        errorMessage = nil

        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmed)
            transientNotice = "Check your email for a link to reset your password."
        } catch {
            errorMessage = AuthEmailErrorMapper.message(for: error)
        }
    }

    func sendPhoneVerificationCode() async {
        let phone = Self.normalizedE164Phone(phoneNumber)
        guard phone.count >= 8 else {
            errorMessage = "Enter a full number with country code, e.g. +15555550100."
            return
        }

        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        let helper = PhoneAuthUIHelper(presenter: topViewController())
        phoneAuthUIHelper = helper

        do {
            let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: helper)
            verificationID = id
            isPhoneCodeSent = true
            errorMessage = nil
        } catch {
            errorMessage = AuthEmailErrorMapper.message(for: error)
        }

        phoneAuthUIHelper = nil
    }

    func verifyPhoneCode() async {
        guard let verificationID else {
            errorMessage = "Phone verification has not been started yet."
            return
        }

        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: phoneVerificationCode
        )

        do {
            _ = try await Auth.auth().signIn(with: credential)
            errorMessage = nil
        } catch {
            errorMessage = AuthEmailErrorMapper.message(for: error)
        }
    }

    #if canImport(GoogleSignIn)
    func signInWithGoogle() async {
        guard let rootVC = topViewController() else {
            errorMessage = "Could not find a presentation context for Google sign-in."
            return
        }
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            errorMessage = """
            Missing CLIENT_ID in GoogleService-Info.plist. In Firebase Console → Project settings → \
            Your apps → download the iOS config again. The plist must include CLIENT_ID and REVERSED_CLIENT_ID.
            """
            return
        }

        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in did not return an ID token."
                return
            }

            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            _ = try await Auth.auth().signIn(with: credential)
            errorMessage = nil
        } catch {
            errorMessage = AuthEmailErrorMapper.message(for: error)
        }
    }
    #else
    func signInWithGoogle() async {
        errorMessage = "Google Sign-In SDK is not linked yet. Add GoogleSignIn package in Xcode."
    }
    #endif

    private func setLoading(_ value: Bool) async {
        await MainActor.run {
            self.isLoading = value
        }
    }

    #if canImport(UIKit)
    private func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    private func topViewController(
        _ root: UIViewController? = nil
    ) -> UIViewController? {
        let scene = activeWindowScene()
        let resolvedRoot = root ?? scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController

        if let nav = resolvedRoot as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = resolvedRoot as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        if let presented = resolvedRoot?.presentedViewController {
            return topViewController(presented)
        }
        return resolvedRoot
    }
    #endif

    private static func normalizedE164Phone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+") {
            return "+" + trimmed.dropFirst().filter(\.isNumber)
        }
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 {
            return "+1" + digits
        }
        if digits.count == 11, digits.hasPrefix("1") {
            return "+" + digits
        }
        if !digits.isEmpty {
            return "+" + digits
        }
        return ""
    }
}
