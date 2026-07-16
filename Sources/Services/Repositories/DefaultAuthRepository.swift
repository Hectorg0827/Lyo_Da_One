import Foundation

// MARK: - Default Auth Repository
class DefaultAuthRepository: AuthRepository {

    private let networkClient = NetworkClient.shared
    private let tokenManager = TokenManager.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - Authentication

    func login(email: String, password: String) async throws -> User {
        struct LoginResponse: Codable {
            let user: User
            let accessToken: String
            let refreshToken: String?

            enum CodingKeys: String, CodingKey {
                case user
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
            }
        }

        let response: LoginResponse = try await networkClient.request(
            Endpoints.Auth.login(email: email, password: password),
            cachePolicy: .reloadIgnoringCache
        )

        // Store tokens
        await tokenManager.setToken(response.accessToken)
        if let refreshToken = response.refreshToken {
            await tokenManager.setRefreshToken(refreshToken)
        }
        await tokenManager.setUserId(String(response.user.id))

        logger.log("✅ Login successful: \(response.user.name)")
        return response.user
    }

    func register(email: String, password: String, name: String) async throws -> User {
        // Backend returns just the user, not tokens
        let user: User = try await networkClient.request(
            Endpoints.Auth.register(email: email, password: password, name: name),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Registration successful: \(user.name)")
        
        // Now login to get tokens
        return try await login(email: email, password: password)
    }

    func logout() async throws {
        // Call logout endpoint
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await networkClient.request(
            Endpoints.Auth.logout,
            cachePolicy: .reloadIgnoringCache
        )

        // Clear local tokens
        await tokenManager.clearAll()

        logger.log("✅ Logout successful")
    }

    func refreshToken() async throws -> String {
        guard let refreshToken = await tokenManager.getRefreshToken() else {
            throw LyoError.network(.unauthorized)
        }

        struct RefreshResponse: Codable {
            let accessToken: String
            let refreshToken: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
            }
        }

        let response: RefreshResponse = try await networkClient.request(
            Endpoints.Auth.refresh(refreshToken: refreshToken),
            cachePolicy: .reloadIgnoringCache
        )

        // Store new tokens
        await tokenManager.setToken(response.accessToken)
        if let newRefreshToken = response.refreshToken {
            await tokenManager.setRefreshToken(newRefreshToken)
        }

        logger.log("✅ Token refreshed")
        return response.accessToken
    }

    func getCurrentUser() async throws -> User {
        let user: User = try await networkClient.request(
            Endpoints.Auth.profile,
            cachePolicy: .default // Cache for 5 minutes
        )

        logger.log("✅ Current user fetched: \(user.name)")
        return user
    }

    func updateProfile(name: String?, avatar: String?) async throws -> User {
        let user: User = try await networkClient.request(
            Endpoints.Auth.updateProfile(name: name, avatar: avatar),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Profile updated: \(user.name)")
        return user
    }
}

// MARK: - Mock Auth Repository
class MockAuthRepository: AuthRepository {

    private var isAuthenticated = false
    private var currentUser: User?

    func login(email: String, password: String) async throws -> User {
        try await Task.sleep(nanoseconds: 500_000_000)

        let user = User(
            id: Int.random(in: 1000...9999),
            email: email,
            name: "Test User",
            avatarURL: nil,
            createdAt: Date(),
            level: 5,
            xp: 2500,
            streak: 0,
            totalLessonsCompleted: 0,
            achievements: []
        )

        isAuthenticated = true
        currentUser = user
        return user
    }

    func register(email: String, password: String, name: String) async throws -> User {
        try await Task.sleep(nanoseconds: 500_000_000)

        let user = User(
            id: Int.random(in: 1000...9999),
            email: email,
            name: name,
            avatarURL: nil,
            createdAt: Date(),
            level: 1,
            xp: 0,
            streak: 0,
            totalLessonsCompleted: 0,
            achievements: []
        )

        isAuthenticated = true
        currentUser = user
        return user
    }

    func logout() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        isAuthenticated = false
        currentUser = nil
    }

    func refreshToken() async throws -> String {
        try await Task.sleep(nanoseconds: 300_000_000)
        return "mock_token_\(UUID().uuidString)"
    }

    func getCurrentUser() async throws -> User {
        try await Task.sleep(nanoseconds: 200_000_000)

        if let user = currentUser {
            return user
        }

        throw LyoError.network(.unauthorized)
    }

    func updateProfile(name: String?, avatar: String?) async throws -> User {
        try await Task.sleep(nanoseconds: 300_000_000)

        guard var user = currentUser else {
            throw LyoError.network(.unauthorized)
        }

        if let name = name {
            user = User(
                id: user.id,
                email: user.email,
                name: name,
                avatarURL: avatar ?? user.avatarURL,
                createdAt: user.createdAt,
                level: user.level,
                xp: user.xp,
                streak: user.streak,
                totalLessonsCompleted: user.totalLessonsCompleted,
                achievements: user.achievements
            )
        }

        currentUser = user
        return user
    }
}
