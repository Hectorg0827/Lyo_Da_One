import Foundation
import Combine
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
import UIKit

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
            print("❌ Backend login failed: \(error.localizedDescription)")
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
            print("❌ Backend registration failed: \(error.localizedDescription)")
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
            print("❌ Google sign-in failed: \(error.localizedDescription)")
            self.error = "Couldn't sign you in with Google. Please try again."
        }
        #else
        error = "Google sign-in isn't available in this version of the app."
        #endif
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

extension AuthService {
    func deleteAccount() async throws {
        logout()
    }
}
