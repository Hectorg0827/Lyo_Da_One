import Foundation
import Combine

/// Centralized user session management
class UserSessionManager: ObservableObject {
    static let shared = UserSessionManager()

    @Published var currentUser: User?

    private init() {}

    /// Current user ID, returns nil if no user is logged in
    var currentUserID: String? {
        guard let user = currentUser else { return nil }
        return String(user.id)
    }

    /// Set the current user (called by RootViewModel)
    func setCurrentUser(_ user: User?) {
        currentUser = user
    }

    /// Check if a user ID matches the current user
    func isCurrentUser(_ userID: String) -> Bool {
        guard let currentID = currentUserID else { return false }
        return currentID == userID
    }

    /// Get current user's string ID safely
    var safeCurrentUserID: String {
        return currentUserID ?? "anonymous"
    }
}