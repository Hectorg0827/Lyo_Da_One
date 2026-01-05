import Foundation
import AuthenticationServices
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
    
    /// Enter demo mode - allows using app with mock data
    func enterDemoMode() {
        Task { @MainActor in
            self.currentUserName = "Demo User"
            self.currentUserEmail = "demo@lyo.app"
            self.isDemoMode = true
            self.authToken = nil  // No real token in demo mode
            self.saveUserSession(name: "Demo User", email: "demo@lyo.app")
            UserDefaults.standard.set(true, forKey: demoModeKey)
            self.isAuthenticated = true
            self.isLoading = false
            print("📱 Entered Demo Mode - using mock data")
        }
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
    
    /// Local authentication fallback when backend is unavailable
    private func performLocalAuth(email: String, name: String?) async {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let userName = name ?? email.components(separatedBy: "@").first ?? "User"
        
        await MainActor.run {
            self.currentUserName = userName
            self.currentUserEmail = email
            self.saveUserSession(name: userName, email: email)
            self.isAuthenticated = true
            self.isLoading = false
            self.error = nil
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
    
    // MARK: - Apple Sign In
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let email = appleIDCredential.email
                // let fullName = appleIDCredential.fullName
                
                // In a real app, you would send the identityToken and authorizationCode to your backend
                // let identityToken = appleIDCredential.identityToken
                // let authCode = appleIDCredential.authorizationCode
                
                print("Apple Sign In Success: \(userIdentifier) \(String(describing: email))")
                
                // Mock backend call
                Task {
                    await MainActor.run { isLoading = true }
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await MainActor.run {
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                }
            }
        case .failure(let error):
            print("Apple Sign In Failed: \(error.localizedDescription)")
            self.error = "Apple Sign In failed."
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() {
        #if canImport(GoogleSignIn)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ No root view controller found for Google Sign In")
            return
        }
        
        Task { @MainActor in
            self.isLoading = true
            self.error = nil
            
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                let user = result.user
                
                let email = user.profile?.email ?? ""
                let name = user.profile?.name ?? email.components(separatedBy: "@").first ?? "User"
                
                guard let idToken = user.idToken?.tokenString else {
                    print("❌ Google Sign In Failed: No ID Token")
                    self.error = "Failed to get ID token from Google"
                    self.isLoading = false
                    return
                }
                
                print("✅ Google Sign In Success: \(email)")
                
                #if canImport(FirebaseAuth)
                // Exchange Google ID Token for Firebase Credential
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)
                
                // Sign in to Firebase
                let firebaseResult = try await Auth.auth().signIn(with: credential)
                let firebaseUser = firebaseResult.user
                
                // Get Firebase ID Token
                let firebaseIdToken = try await firebaseUser.getIDToken()
                print("✅ Firebase Auth Success: \(firebaseUser.uid)")
                
                // Authenticate with Backend using Firebase ID Token
                do {
                    let backendUser = try await repository.loginWithGoogle(idToken: firebaseIdToken)
                    self.currentUserName = backendUser.name
                    self.currentUserEmail = backendUser.email
                    self.isDemoMode = false
                    UserDefaults.standard.set(false, forKey: demoModeKey)
                    self.saveUserSession(name: backendUser.name, email: backendUser.email)
                    self.isAuthenticated = true
                    print("✅ Backend auth successful for: \(backendUser.email)")
                } catch {
                    // Backend Firebase auth failed - try to register/login with email directly
                    print("⚠️ Backend Firebase auth failed: \(error.localizedDescription)")
                    print("🔄 Attempting backend login with Google email...")
                    
                    do {
                        // Try to login first (user might already exist)
                        // bcrypt requires max 72 BYTES - properly truncate UTF-8 data
                        let fullPassword = "Google_\(firebaseUser.uid)_Auth"
                        let passwordData = Data(fullPassword.utf8.prefix(72))
                        let tempPassword = String(decoding: passwordData, as: UTF8.self)
                        let backendUser = try await repository.login(email: email, password: tempPassword)
                        
                        self.currentUserName = backendUser.name
                        self.currentUserEmail = backendUser.email
                        self.isDemoMode = false
                        UserDefaults.standard.set(false, forKey: demoModeKey)
                        self.saveUserSession(name: backendUser.name, email: backendUser.email)
                        self.isAuthenticated = true
                        print("✅ Backend login successful for Google user: \(email)")
                    } catch {
                        // Login failed - try to register
                        print("🔄 Login failed, attempting registration...")
                        do {
                            // bcrypt requires max 72 BYTES - properly truncate UTF-8 data
                            let fullPassword = "Google_\(firebaseUser.uid)_Auth"
                            let passwordData = Data(fullPassword.utf8.prefix(72))
                            let tempPassword = String(decoding: passwordData, as: UTF8.self)
                            let backendUser = try await repository.register(email: email, password: tempPassword, name: name)
                            
                            self.currentUserName = backendUser.name
                            self.currentUserEmail = backendUser.email
                            self.isDemoMode = false
                            UserDefaults.standard.set(false, forKey: demoModeKey)
                            self.saveUserSession(name: backendUser.name, email: backendUser.email)
                            self.isAuthenticated = true
                            print("✅ Backend registration successful for Google user: \(email)")
                        } catch let registrationError {
                            // Both login and register failed - cannot use app without backend auth
                            print("❌ Backend auth completely failed: \(registrationError.localizedDescription)")
                            print("⚠️ Firebase UID cannot be used as backend user ID - would cause 403/500 errors")
                            
                            // Do NOT store Firebase UID as userId - it's incompatible with backend!
                            // Show error to user instead of silently failing
                            self.error = "Unable to connect to server. Please try again later."
                            self.isLoading = false
                            self.isAuthenticated = false
                            return
                        }
                    }
                }
                #else
                // FirebaseAuth not available: cannot proceed - backend requires Firebase auth
                print("❌ FirebaseAuth not available. Cannot authenticate with backend.")
                self.error = "Authentication unavailable. Please update the app."
                self.isLoading = false
                self.isAuthenticated = false
                return
                #endif
                
                self.isLoading = false
                
            } catch {
                print("❌ Google Sign In Failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
        #else
        // Fallback if SDK is not available
        print("⚠️ GoogleSignIn SDK not imported")
        Task {
            await performLocalAuth(email: "google_user@example.com", name: "Google User")
        }
        #endif
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
