import Foundation
import Combine
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
import AuthenticationServices
import CryptoKit
import Security
import UIKit
import os

class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUserName: String = ""
    @Published var currentUserEmail: String = ""
    @Published var isDemoMode: Bool = false  // NEW: Track if we're in demo mode
    
    // Auth token for API requests
    var authToken: String? {
        didSet {
            if let token = authToken {
                KeychainHelper.shared.saveString(token, forKey: tokenKey)
            } else {
                KeychainHelper.shared.delete(forKey: tokenKey)
            }
        }
    }
    
    private let repository = LyoRepository.shared
    
    // UserDefaults keys for persistence
    private let userNameKey = "lyo_user_name"
    private let userEmailKey = "lyo_user_email"
    private let isLoggedInKey = "lyo_is_logged_in"
    private let tokenKey = "lyo_auth_token"
    private let demoModeKey = "lyo_demo_mode"
    
    static let shared = AuthService()
    
    override init() {
        super.init()
        // Check if user was previously logged in
        if UserDefaults.standard.bool(forKey: isLoggedInKey) {
            self.currentUserName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
            self.currentUserEmail = UserDefaults.standard.string(forKey: userEmailKey) ?? ""
            self.authToken = KeychainHelper.shared.readString(forKey: tokenKey)
            self.isDemoMode = UserDefaults.standard.bool(forKey: demoModeKey)
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Demo Mode
    
    /// Enter demo mode - allows using app with mock data.
    /// DEBUG-only: in release builds this is a no-op so the app can never be
    /// "authenticated" without a real backend token.
    func enterDemoMode() {
        #if DEBUG
        Task { @MainActor in
            self.currentUserName = "Demo User"
            self.currentUserEmail = "demo@lyo.app"
            self.isDemoMode = true
            self.authToken = nil  // No real token in demo mode
            self.saveUserSession(name: "Demo User", email: "demo@lyo.app")
            UserDefaults.standard.set(true, forKey: demoModeKey)
            self.isAuthenticated = true
            self.isLoading = false
            Log.auth.info("Entered Demo Mode - using mock data (DEBUG only)")
        }
        #else
        Log.auth.warning("enterDemoMode() called in a release build — ignored")
        #endif
    }
    
    // MARK: - Email / Password
    
    func login(email: String, password: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let user = try await repository.login(email: email, password: password)
            await MainActor.run {
                self.currentUserName = user.name
                self.currentUserEmail = user.email
                self.isDemoMode = false // Ensure we are NOT in demo mode
                self.saveUserSession(name: user.name, email: user.email)
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            // Backend failed - Show error instead of falling back to mock
            Log.auth.debugLine("❌ Backend login failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func register(name: String, email: String, password: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let user = try await repository.register(email: email, password: password, name: name)
            await MainActor.run {
                self.currentUserName = user.name
                self.currentUserEmail = user.email
                self.isDemoMode = false // Ensure we are NOT in demo mode
                self.saveUserSession(name: user.name, email: user.email)
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            // Backend failed - Show error instead of falling back to mock
            Log.auth.debugLine("❌ Backend registration failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func saveUserSession(name: String, email: String) {
        UserDefaults.standard.set(name, forKey: userNameKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
        UserDefaults.standard.set(true, forKey: isLoggedInKey)
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.set(false, forKey: isLoggedInKey)
        UserDefaults.standard.set(false, forKey: demoModeKey)
        KeychainHelper.shared.delete(forKey: tokenKey)
        
        Task {
            await MainActor.run {
                self.currentUserName = ""
                self.currentUserEmail = ""
                self.authToken = nil
                self.isDemoMode = false
                self.isAuthenticated = false
            }
        }
    }
    
    // MARK: - Google Sign In

    /// Signs in with Google: Google confirms the account, Firebase turns that
    /// into an ID token, and the API exchanges it for LYO's tokens
    /// (POST /auth/firebase), creating the account the first time.
    @MainActor
    func signInWithGoogle() async {
        #if canImport(GoogleSignIn) && canImport(FirebaseAuth)
        guard let presenter = Self.topViewController() else {
            error = "Couldn't open Google sign-in. Please try again."
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let googleIdToken = result.user.idToken?.tokenString else {
                error = "Google didn't confirm your account. Please try again."
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: googleIdToken,
                                                           accessToken: result.user.accessToken.tokenString)
            let firebaseUser = try await Auth.auth().signIn(with: credential).user
            let firebaseIdToken = try await firebaseUser.getIDToken()
            let user = try await repository.loginWithGoogle(idToken: firebaseIdToken)
            currentUserName = user.name
            currentUserEmail = user.email
            isDemoMode = false
            UserDefaults.standard.set(false, forKey: demoModeKey)
            saveUserSession(name: user.name, email: user.email)
            isAuthenticated = true
        } catch GIDSignInError.canceled {
            // The learner closed Google's sheet; nothing went wrong.
        } catch {
            // No fallback: without the API's confirmation there is no LYO session.
            Log.auth.debugLine("❌ Google sign-in failed: \(error.localizedDescription)")
            self.error = "Couldn't sign you in with Google. Please try again."
        }
        #else
        error = "Google sign-in isn't available in this version of the app."
        #endif
    }

    // MARK: - Sign in with Apple

    /// The unhashed nonce of the Apple request in progress. Apple signs its
    /// SHA-256 into the identity token; Firebase checks it against this one.
    private var currentAppleNonce: String?

    /// Fills in the request the Sign in with Apple button is about to send
    /// (on the main thread, from the button's onRequest).
    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        error = nil
    }

    /// Signs in with Apple: Apple confirms the account, Firebase turns that
    /// into an ID token, and the API exchanges it for LYO's tokens
    /// (POST /auth/firebase) exactly as it does for Google.
    @MainActor
    func finishAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        #if canImport(FirebaseAuth)
        let appleCredential: ASAuthorizationAppleIDCredential
        switch result {
        case .failure(let failure):
            if (failure as? ASAuthorizationError)?.code != .canceled {
                Log.auth.error("Apple sign-in failed: \(failure.localizedDescription)")
                error = "Couldn't sign you in with Apple. Please try again."
            }
            // Otherwise the learner closed Apple's sheet; nothing went wrong.
            return
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = "Couldn't sign you in with Apple. Please try again."
                return
            }
            appleCredential = credential
        }
        guard let nonce = currentAppleNonce,
              let tokenData = appleCredential.identityToken,
              let appleIdToken = String(data: tokenData, encoding: .utf8) else {
            error = "Apple didn't confirm your account. Please try again."
            return
        }
        currentAppleNonce = nil
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let credential = OAuthProvider.appleCredential(withIDToken: appleIdToken,
                                                           rawNonce: nonce,
                                                           fullName: appleCredential.fullName)
            let firebaseUser = try await Auth.auth().signIn(with: credential).user
            // Apple shares the learner's name only the very first time. Keep it
            // on the Firebase account so the ID token (and the LYO account the
            // API creates from it) carries it, even if this attempt fails later.
            let appleName = Self.displayName(from: appleCredential.fullName)
            if let appleName, (firebaseUser.displayName ?? "").isEmpty {
                let change = firebaseUser.createProfileChangeRequest()
                change.displayName = appleName
                try? await change.commitChanges()
            }
            let firebaseIdToken = try await firebaseUser.idTokenForcingRefresh(appleName != nil)
            let user = try await repository.loginWithFirebase(idToken: firebaseIdToken)
            // A learner who hid their email signs in with an Apple relay
            // address (…@privaterelay.appleid.com); it is a working address, so
            // it is kept as is. Never show that relay address as the name.
            let name = user.name.trimmingCharacters(in: .whitespaces).isEmpty
                ? (appleName ?? firebaseUser.displayName ?? "")
                : user.name
            currentUserName = name
            currentUserEmail = user.email
            isDemoMode = false
            UserDefaults.standard.set(false, forKey: demoModeKey)
            saveUserSession(name: name, email: user.email)
            isAuthenticated = true
        } catch {
            // No fallback: without the API's confirmation there is no LYO session.
            Log.auth.error("Apple sign-in failed: \(error.localizedDescription)")
            self.error = "Couldn't sign you in with Apple. Please try again."
        }
        #else
        error = "Sign in with Apple isn't available in this version of the app."
        #endif
    }

    /// "Ada Lovelace" from Apple's name parts, or nil when Apple sent none
    /// (every sign-in after the first).
    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, length, &bytes) != errSecSuccess {
            // SecRandom effectively never fails; fall back to Swift's CSPRNG.
            bytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The screen on top, so Google's sheet opens above any sheet already showing.
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    
    // MARK: - Helper Methods
    
    /// Get current user ID for analytics and other services
    /// Returns email as user ID since that's what we use for authentication
    func getCurrentUserId() async throws -> String? {
        guard isAuthenticated else {
            return nil
        }
        // Use email as user ID
        return currentUserEmail.isEmpty ? nil : currentUserEmail
    }
}

// MARK: - Account Deletion

/// Why an account could not be deleted, in words for the learner.
enum AccountDeletionError: LocalizedError {
    case appleConfirmationNeeded
    case server(Error)

    var errorDescription: String? {
        switch self {
        case .appleConfirmationNeeded:
            return "Your account was not deleted. Because you signed in with Apple, please confirm with Apple to delete it."
        case .server(let error):
            if case .network(.noInternetConnection)? = error as? LyoError {
                return "Your account was not deleted. You're offline; please connect to the internet and try again."
            }
            return "Your account was not deleted. Something went wrong on our side; please try again in a moment."
        }
    }
}

extension AuthService {
    /// Permanently deletes the learner's LYO account (DELETE /auth/me).
    ///
    /// Only after the API confirms (200/204) does this sign out of Apple,
    /// Google and Firebase and erase this device's tokens and caches. If the
    /// API refuses or can't be reached it throws and changes nothing: the
    /// learner stays signed in and can try again.
    @MainActor
    func deleteAccount() async throws {
        // Apple requires apps to revoke Sign in with Apple when the account is
        // deleted. That needs a fresh authorization code, so a learner who
        // signed in with Apple confirms once more before anything is deleted.
        var appleAuthorizationCode: String?
        #if canImport(FirebaseAuth)
        if Auth.auth().currentUser?.providerData.contains(where: { $0.providerID == "apple.com" }) == true {
            appleAuthorizationCode = try await Self.confirmWithApple()
        }
        #endif

        do {
            _ = try await NetworkClient.shared.requestRawData(Endpoints.Auth.deleteAccount)
        } catch {
            Log.auth.error("Account deletion failed: \(error.localizedDescription)")
            throw AccountDeletionError.server(error)
        }
        Log.auth.info("Account deleted on the server")

        #if canImport(FirebaseAuth)
        if let appleAuthorizationCode {
            do {
                try await Auth.auth().revokeToken(withAuthorizationCode: appleAuthorizationCode)
            } catch {
                // The LYO account is already gone; the learner can still remove
                // LYO under Settings > Apple ID > Sign in with Apple.
                Log.auth.error("Apple token revocation failed: \(error.localizedDescription)")
            }
        }
        try? await Auth.auth().currentUser?.delete()
        try? Auth.auth().signOut()
        #endif
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif

        await Self.eraseLocalAccountData()
        logout()
    }

    /// Erases everything this device kept about the deleted account.
    @MainActor
    private static func eraseLocalAccountData() async {
        await TokenManager.shared.clearAll()
        await NetworkCache.shared.clearAll()
        URLCache.shared.removeAllCachedResponses()
        UnifiedChatPersistence.shared.clearAllConversations()
        GeneratedContentStore.shared.clearAll()
        UIStackStore.shared.removeAll()
        LearningProfileService.shared.clear()
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }

    /// Asks Apple for a fresh authorization code (Face ID / passcode sheet).
    /// Closing the sheet throws `appleConfirmationNeeded`, so nothing is deleted.
    @MainActor
    private static func confirmWithApple() async throws -> String {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = []
        let authorization: ASAuthorization
        do {
            authorization = try await AppleAuthorizationRequester().perform(request)
        } catch {
            if (error as? ASAuthorizationError)?.code != .canceled {
                Log.auth.error("Apple confirmation failed: \(error.localizedDescription)")
            }
            throw AccountDeletionError.appleConfirmationNeeded
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let codeData = credential.authorizationCode,
              let code = String(data: codeData, encoding: .utf8) else {
            throw AccountDeletionError.appleConfirmationNeeded
        }
        return code
    }
}

/// Runs one Apple ID request outside the SwiftUI button (account deletion
/// asks Apple to confirm again) and hands back its result.
private final class AppleAuthorizationRequester: NSObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var controller: ASAuthorizationController?
    private var anchor: ASPresentationAnchor!

    @MainActor
    func perform(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.windows.first(where: \.isKeyWindow) ?? scene?.windows.first else {
            throw ASAuthorizationError(.failed)
        }
        anchor = window
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation?.resume(returning: authorization)
        continuation = nil
        self.controller = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        self.controller = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor
    }
}
