import Foundation
import FirebaseAuth
import Combine
import AuthenticationServices
import CryptoKit
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

    @Published var phoneNumber: String = ""
    @Published var phoneVerificationCode: String = ""
    @Published var isPhoneCodeSent: Bool = false

    private(set) var currentNonce: String?
    private var verificationID: String?

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
    }

    func signInWithEmail(email: String, password: String) async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createAccountWithEmail(email: String, password: String) async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendPhoneVerificationCode() async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
            verificationID = id
            isPhoneCodeSent = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
            errorMessage = error.localizedDescription
        }
    }

    #if canImport(GoogleSignIn)
    func signInWithGoogle() async {
        guard let rootVC = topViewController() else {
            errorMessage = "Could not find a presentation context for Google sign-in."
            return
        }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing Firebase client ID. Check GoogleService-Info.plist."
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

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #else
    func signInWithGoogle() async {
        errorMessage = "Google Sign-In SDK is not linked yet. Add GoogleSignIn package in Xcode."
    }
    #endif

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }

        do {
            switch result {
            case .success(let authResults):
                guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                    errorMessage = "Invalid Apple ID credential."
                    return
                }
                guard let nonce = currentNonce else {
                    errorMessage = "Invalid sign-in state. Please try again."
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    errorMessage = "Unable to fetch Apple identity token."
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMessage = "Unable to decode Apple identity token."
                    return
                }

                let credential = OAuthProvider.credential(
                    withProviderID: "apple.com",
                    idToken: idTokenString,
                    rawNonce: nonce
                )
                _ = try await Auth.auth().signIn(with: credential)
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setLoading(_ value: Bool) async {
        await MainActor.run {
            self.isLoading = value
        }
    }

    #if canImport(GoogleSignIn)
    private func topViewController(
        _ root: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(presented)
        }
        return root
    }
    #endif

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}
