//
//  FirebaseAuthManager.swift
//  Lyo
//
//  Provides centralized access to Firebase Auth state
//

import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth

/// Centralized manager for Firebase Authentication state
/// Used by NetworkClient to refresh tokens when needed
@MainActor
class FirebaseAuthManager {
    
    /// Returns the current Firebase user if one is signed in
    /// Using FirebaseAuth.User to avoid conflict with Lyo.User
    static var currentUser: FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    /// Refresh the Firebase ID token and return it
    /// - Parameter forceRefresh: If true, forces a refresh even if token hasn't expired
    /// - Returns: Fresh Firebase ID token
    static func refreshToken(forceRefresh: Bool = true) async throws -> String {
        guard let user = currentUser else {
            throw LyoError.network(.unauthorized)
        }
        
        // getIDTokenForcingRefresh is the correct async/await method
        return try await user.getIDToken()
    }
    
    /// Force refresh the token (bypass cache)
    static func forceRefreshToken() async throws -> String {
        guard let user = currentUser else {
            throw LyoError.network(.unauthorized)
        }
        
        // Use completion handler based method for force refresh
        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(true) { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: LyoError.network(.unauthorized))
                }
            }
        }
    }
    
    /// Check if a user is currently signed in with Firebase
    static var isSignedIn: Bool {
        return currentUser != nil
    }
    
    /// Get the current user's UID
    static var currentUserId: String? {
        return currentUser?.uid
    }
}

#else

/// Stub implementation when FirebaseAuth is not available
@MainActor
class FirebaseAuthManager {
    static var currentUser: Any? { nil }
    static var isSignedIn: Bool { false }
    static var currentUserId: String? { nil }
    
    static func refreshToken(forceRefresh: Bool = true) async throws -> String {
        throw LyoError.network(.unauthorized)
    }
    
    static func forceRefreshToken() async throws -> String {
        throw LyoError.network(.unauthorized)
    }
}

#endif
