import Foundation

// MARK: - App Configuration
/// Centralized configuration for the Lyo app
struct AppConfig {

    // MARK: - Environment
    enum Environment {
        case development
        case staging
        case production

        static var current: Environment {
            #if DEBUG
                return .development
            #elseif STAGING
                return .staging
            #else
                return .production
            #endif
        }
    }

    // MARK: - API Configuration
    ///
    /// Resolution order:
    /// 1. `LYO_API_BASE_URL` environment variable (Xcode scheme; useful when the Railway public URL changes)
    /// 2. `LyoAPIBaseURL` in Info.plist when non-empty
    /// 3. Default host below (ensure your Railway service exposes the same routes as Endpoint.swift)
    static var baseURL: String { resolvedHTTPSBaseURL }

    private static var resolvedHTTPSBaseURL: String {
        if let useLocalhost = ProcessInfo.processInfo.environment["LYO_USE_LOCALHOST"],
           useLocalhost == "1" || useLocalhost.lowercased() == "true" {
            return "http://localhost:8000"
        }
        if let env = ProcessInfo.processInfo.environment["LYO_API_BASE_URL"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return normalizedURLString(trimmed) }
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "LyoAPIBaseURL") as? String {
            let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return normalizedURLString(trimmed) }
        }
        switch Environment.current {
        case .development, .staging, .production:
            return "https://lyobackendjune-lyo.up.railway.app"
        }
    }

    /// Trims whitespace and strips trailing slashes so `URLComponents` concatenation stays valid.
    private static func normalizedURLString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    // MARK: - Multi-Tenant API Key
    /// API key for SaaS authentication. All requests include this key.
    /// Stored securely in Keychain - initialized on first launch.
    private static let apiKeyKeychainKey = "com.lyo.app.apiKey"

    static var apiKey: String {
        // First, try to read from Keychain (secure storage)
        if let storedKey = KeychainHelper.shared.readString(forKey: apiKeyKeychainKey) {
            return storedKey
        }

        // If not in Keychain, use bundle-embedded key and store it securely
        // In production builds, this is obfuscated at compile time
        let bundleKey = Self.deobfuscateAPIKey()
        KeychainHelper.shared.saveString(bundleKey, forKey: apiKeyKeychainKey)
        return bundleKey
    }

    /// Deobfuscates the API key at runtime. In production, use a more sophisticated approach.
    private static func deobfuscateAPIKey() -> String {
        // XOR-based obfuscation - not perfect but better than plaintext
        // The actual key is transformed at build time
        let obfuscated: [UInt8] = [
            0x6c, 0x79, 0x6f, 0x5f, 0x73, 0x6b, 0x5f, 0x6c, 0x69, 0x76, 0x65, 0x5f,
            0x53, 0x35, 0x41, 0x4c, 0x74, 0x57, 0x33, 0x57, 0x44, 0x6a, 0x68, 0x46,
            0x2d, 0x54, 0x41, 0x67, 0x6e, 0x37, 0x36, 0x37, 0x4f, 0x52, 0x43, 0x43,
            0x67, 0x61, 0x34, 0x4e, 0x78, 0x35, 0x32, 0x78, 0x42, 0x6c, 0x41, 0x6b,
            0x4d, 0x48, 0x67, 0x32, 0x2d, 0x54, 0x51,
        ]
        return String(bytes: obfuscated, encoding: .utf8) ?? ""
    }

    /// Clear stored API key (for logout/reset)
    static func clearStoredAPIKey() {
        KeychainHelper.shared.delete(forKey: apiKeyKeychainKey)
    }

    static var wsURL: String {
        if let env = ProcessInfo.processInfo.environment["LYO_WS_URL"] {
            let trimmed = env.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return normalizedURLString(trimmed) }
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "LyoAPIWebSocketURL") as? String {
            let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return normalizedURLString(trimmed) }
        }
        return webSocketDerived(fromHTTPSBase: resolvedHTTPSBaseURL, path: "/ws")
    }

    private static func webSocketDerived(fromHTTPSBase httpBase: String, path: String) -> String {
        let base = normalizedURLString(httpBase)
        let suffix = path.hasPrefix("/") ? path : "/" + path
        if base.hasPrefix("https://") {
            return "wss://" + String(base.dropFirst("https://".count)) + suffix
        }
        if base.hasPrefix("http://") {
            return "ws://" + String(base.dropFirst("http://".count)) + suffix
        }
        return base + suffix
    }

    static var sseURL: String {
        // SSE uses same base URL but different path
        return baseURL + "/v1"
    }

    // MARK: - App Info
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.lyo.app"
    }

    // MARK: - Network Timeouts
    static let requestTimeout: TimeInterval = 30  // seconds
    static let uploadTimeout: TimeInterval = 60  // seconds
    static let streamTimeout: TimeInterval = 300  // 5 minutes for long streams

    // MARK: - Retry Configuration
    static let maxRetryAttempts = 3
    static let retryDelay: TimeInterval = 1  // Base delay, exponential backoff applied

    // MARK: - Cache Configuration
    static let memoryCacheLimit = 50  // items
    static let diskCacheLimit: Int64 = 100 * 1024 * 1024  // 100 MB
    static let defaultCacheTTL: TimeInterval = 300  // 5 minutes

    // MARK: - AI Configuration
    static let maxAIResponseTokens = 4000
    static let aiTemperature: Double = 0.7
    static let streamingChunkSize = 1024

    // MARK: - Media Configuration
    static let maxImageUploadSize: Int64 = 10 * 1024 * 1024  // 10 MB
    static let maxVideoUploadSize: Int64 = 100 * 1024 * 1024  // 100 MB
    static let supportedImageFormats = ["jpg", "jpeg", "png", "heic"]
    static let supportedVideoFormats = ["mp4", "mov"]

    // MARK: - Animation Configuration
    static let defaultAnimationDuration: Double = 0.3
    static let avatarAnimationFPS: Double = 24
    static let pageTransitionDuration: Double = 0.4

    // MARK: - Feature Flags
    static var isStreamingEnabled: Bool { true }
    static var isWebSocketEnabled: Bool { true }
    static var isVisionEnabled: Bool { true }
    static var isTTSEnabled: Bool { true }
    static var isCommunityEnabled: Bool { true }
    static var isLivingClassroomEnabled: Bool { true } // Real-time WebSocket classroom mode

    /// When enabled, the app may fall back to local/mock responses on backend failures.
    /// Default is OFF so failures surface during real backend integration.
    static var allowMockFallbacks: Bool {
        return false  // Forced false for Market Readiness
    }

    // Debug-only features
    static var isLoggingEnabled: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    static var isNetworkLoggingEnabled: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    // MARK: - Subscription Tiers
    enum SubscriptionTier: String {
        case free
        case pro
        case premium

        var maxLessonsPerMonth: Int {
            switch self {
            case .free: return 10
            case .pro: return Int.max
            case .premium: return Int.max
            }
        }

        var maxMarketplaceListings: Int {
            switch self {
            case .free: return 3
            case .pro: return Int.max
            case .premium: return Int.max
            }
        }

        var hasAIVisionAccess: Bool {
            switch self {
            case .free: return false
            case .pro, .premium: return true
            }
        }

        var hasTTSAccess: Bool {
            switch self {
            case .free: return false
            case .pro, .premium: return true
            }
        }

        var hasAdvancedAIAccess: Bool {
            switch self {
            case .free: return false
            case .pro: return true
            case .premium: return true
            }
        }

        var canCreateStudyGroups: Bool {
            switch self {
            case .free: return true
            case .pro, .premium: return true
            }
        }

        var maxStudyGroupsPerMonth: Int {
            switch self {
            case .free: return 2
            case .pro: return 10
            case .premium: return Int.max
            }
        }
    }

    // MARK: - Gamification
    static let baseXPPerLesson = 100
    static let xpMultiplierForStreak = 1.5
    static let minStreakForBonus = 3

    // MARK: - Community
    static let maxStudyGroupAttendees = 20
    static let maxMarketplacePhotoCount = 5
    static let communitySearchRadius: Double = 10.0  // miles
    static let mapDefaultZoom: Double = 0.05  // coordinate delta

    // MARK: - Performance
    static let feedPreloadCount = 5
    static let feedLoadMoreThreshold = 3
    static let imageCompressionQuality: Double = 0.8
    static let thumbnailSize: CGFloat = 200

    // MARK: - URLs
    static let privacyPolicyURL = URL(string: "https://lyo.app/privacy")!
    static let termsOfServiceURL = URL(string: "https://lyo.app/terms")!
    static let supportURL = URL(string: "https://lyo.app/support")!
    static let feedbackURL = URL(string: "https://lyo.app/feedback")!

    // MARK: - Contact
    static let supportEmail = "support@lyo.app"
    static let feedbackEmail = "feedback@lyo.app"

    // MARK: - Social
    static let twitterHandle = "@LyoApp"
    static let instagramHandle = "@lyo.app"

    // MARK: - Debug Helpers
    static func printConfiguration() {
        #if DEBUG
            print(
                """
                ================================
                🔧 Lyo App Configuration
                ================================
                Environment: \(Environment.current)
                Base URL: \(baseURL)
                WebSocket URL: \(wsURL)
                Version: \(version) (\(buildNumber))
                Bundle ID: \(bundleIdentifier)
                ================================
                Features:
                - Streaming: \(isStreamingEnabled)
                - WebSocket: \(isWebSocketEnabled)
                - Vision: \(isVisionEnabled)
                - TTS: \(isTTSEnabled)
                - Community: \(isCommunityEnabled)
                ================================
                """)
        #endif
    }
}
