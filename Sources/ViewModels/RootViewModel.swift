import Foundation
import SwiftUI
import Combine

// MARK: - Root View Model
/// App-level state management for authentication and user session
@MainActor
class RootViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var colorScheme: ColorScheme?
    @Published var error: LyoError?

    var isDemoMode: Bool {
        currentUser.map { String($0.id) } == "demo-user"
    }

    // MARK: - Dependencies

    private let authRepository: AuthRepository
    private let tokenManager = TokenManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(authRepository: AuthRepository = DefaultAuthRepository()) {
        self.authRepository = authRepository
        loadColorScheme()
    }

    // MARK: - Authentication Check

    func checkAuthStatus() {
        Task {
            isLoading = true

            // Start a timeout task to prevent infinite loading
            Task {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                if isLoading {
                    print("⚠️ Auth check timed out, forcing UI to load")
                    isLoading = false
                }
            }

            // Check if we have a valid token
            if await tokenManager.hasValidToken() {
                do {
                    // Try to fetch current user
                    currentUser = try await authRepository.getCurrentUser()
                    isAuthenticated = true

                    // ✅ Session restored from stored token — start services
                    // (push, subscription sync, cross-device sync), same as login
                    await onUserAuthenticated()
                } catch {
                    // Token expired or invalid
                    handleError(error)
                    isAuthenticated = false
                    await tokenManager.clearTokens()
                }
            } else {
                isAuthenticated = false
            }

            // Small delay for smooth transition
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        // Clear any stale tokens before attempting new login
        await tokenManager.clearTokens()
        
        do {
            currentUser = try await authRepository.login(email: email, password: password)
            isAuthenticated = true
            
            // ✅ Trigger post-login services
            await onUserAuthenticated()
        } catch {
            // No offline "fallback" account: without the API there is no session.
            throw error
        }
    }

    // MARK: - Register

    func register(email: String, password: String, name: String) async throws {
        // Clear any stale tokens before attempting registration
        await tokenManager.clearTokens()
        
        do {
            currentUser = try await authRepository.register(email: email, password: password, name: name)
            isAuthenticated = true

            // ✅ Trigger post-registration services, same as login
            await onUserAuthenticated()
        } catch {
            // No offline "fallback" account: without the API there is no session.
            throw error
        }
    }

    // MARK: - Signed In

    /// Called by the sign-in screens once AuthService holds a session the API
    /// confirmed (its tokens are already in the keychain). Opens the app and
    /// starts the same services a restored session starts, push included.
    func didSignIn() async {
        isAuthenticated = true
        await onUserAuthenticated()
        if let user = try? await authRepository.getCurrentUser() {
            currentUser = user
        }
    }

    // MARK: - Post-Authentication Services
    
    /// Called after successful authentication to initialize services
    private func onUserAuthenticated() async {
        print("🔐 User authenticated - initializing services...")
        
        // 1. Register device for push notifications
        PushNotificationService.shared.onUserLogin()
        
        // 2. Sync subscription/monetization status
        await MonetizationService.shared.syncSubscriptionWithBackend()

        // 3. Connect cross-device sync (same account on web/Android stays
        // live). Fallback/offline sessions have no JWT — the socket could
        // never authenticate, so don't start (and endlessly retry) it.
        if await TokenManager.shared.getToken() != nil {
            SyncService.shared.connect()
        }

        // 4. Request push notification permission if not already granted
        PushNotificationService.shared.checkPermissionStatus { status in
            if status == .notDetermined {
                PushNotificationService.shared.requestPermission { granted, _ in
                    print(granted ? "✅ Push notifications enabled" : "❌ Push notifications denied")
                }
            }
        }
        
        print("✅ Post-authentication services initialized")
    }

    // MARK: - Logout

    func logout() async {
        // Notify services before logout
        await PushNotificationService.shared.onUserLogout()
        SyncService.shared.disconnect()
        
        do {
            try await authRepository.logout()
        } catch {
            handleError(error)
        }

        // Clear local state
        currentUser = nil
        isAuthenticated = false
        await tokenManager.clearTokens()
        
        print("✅ User logged out - services cleaned up")
    }

    /// Called after AuthService.deleteAccount() succeeded. The account no
    /// longer exists, so unlike logout() nothing is sent to /auth/logout.
    func didDeleteAccount() async {
        await PushNotificationService.shared.onUserLogout()
        SyncService.shared.disconnect()
        await tokenManager.clearTokens()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - User Update

    func updateUser(_ updatedUser: User) {
        currentUser = updatedUser
    }

    func refreshUserData() async {
        guard isAuthenticated else { return }

        do {
            currentUser = try await authRepository.getCurrentUser()
        } catch {
            handleError(error)
        }
    }

    func updateProfile(name: String?, avatar: String?) async throws {
        guard isAuthenticated else { return }

        do {
            currentUser = try await authRepository.updateProfile(name: name, avatar: avatar)
        } catch {
            handleError(error)
            throw error
        }
    }

    // MARK: - Color Scheme

    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        saveColorScheme()
    }

    private func loadColorScheme() {
        if let saved = UserDefaults.standard.string(forKey: "colorScheme") {
            switch saved {
            case "light":
                colorScheme = .light
            case "dark":
                colorScheme = .dark
            default:
                colorScheme = nil
            }
        }
    }

    private func saveColorScheme() {
        if let scheme = colorScheme {
            UserDefaults.standard.set(scheme == .light ? "light" : "dark", forKey: "colorScheme")
        } else {
            UserDefaults.standard.removeObject(forKey: "colorScheme")
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let lyoError = error as? LyoError {
            self.error = lyoError
        } else {
            self.error = .network(.serverError(500))
        }
    }

    // MARK: - Computed Properties

    var userDisplayName: String {
        currentUser?.name ?? "User"
    }

    var userLevel: Int {
        currentUser?.level ?? 1
    }

    var userXP: Int {
        currentUser?.xp ?? 0
    }

    var userAvatarURL: String? {
        currentUser?.avatarURL
    }
}

// MARK: - Token Manager Extension
extension TokenManager {
    func hasValidToken() async -> Bool {
        guard let token = await getToken() else { return false }
        // TODO: Add token expiry check if backend provides exp claim
        return !token.isEmpty
    }

    func clearTokens() async {
        await clearAll()
    }
}
