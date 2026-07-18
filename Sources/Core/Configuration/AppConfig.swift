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
    static var baseURL: String {
        switch Environment.current {
        case .development:
            // All three clients use the same canonical backend by default.
            // Set LYO_USE_LOCALHOST=1 in Xcode scheme env vars to use local backend
            if ProcessInfo.processInfo.environment["LYO_USE_LOCALHOST"] == "1" {
                return "http://localhost:8000"
            }
            return "https://api.lyoai.app"
        case .staging:
            return "https://api.lyoai.app"
        case .production:
            return "https://api.lyoai.app"
        }
    }

    // MARK: - Multi-Tenant API Key
    /// API key for SaaS authentication. All requests include this key.
    /// Stored securely in Keychain - initialized on first launch.
    private static let apiKeyKeychainKey = "com.lyo.app.apiKey"

    /// SaaS API key resolution — NO secret is embedded in source.
    /// Resolution order:
    ///   1. Keychain (cached after first resolution)
    ///   2. `LYO_API_KEY` process environment variable (local dev via Xcode scheme)
    ///   3. `LYO_API_KEY` from Info.plist, injected at build time from a gitignored
    ///      xcconfig / CI secret (the `$(...)` guard ignores an unsubstituted placeholder)
    /// If none are present the key is empty and the backend will reject requests —
    /// surfacing a misconfiguration instead of shipping a live credential.
    static var apiKey: String {
        if let storedKey = KeychainHelper.shared.readString(forKey: apiKeyKeychainKey),
           !storedKey.isEmpty {
            return storedKey
        }

        if let envKey = ProcessInfo.processInfo.environment["LYO_API_KEY"], !envKey.isEmpty {
            KeychainHelper.shared.saveString(envKey, forKey: apiKeyKeychainKey)
            return envKey
        }

        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "LYO_API_KEY") as? String,
           !plistKey.isEmpty, !plistKey.hasPrefix("$(") {
            KeychainHelper.shared.saveString(plistKey, forKey: apiKeyKeychainKey)
            return plistKey
        }

        #if DEBUG
        print("⚠️ AppConfig.apiKey is empty — set LYO_API_KEY via the Xcode scheme or an xcconfig/CI secret")
        #endif
        return ""
    }

    /// Inject an API key at runtime (e.g. one issued by the backend per session).
    static func setAPIKey(_ key: String) {
        KeychainHelper.shared.saveString(key, forKey: apiKeyKeychainKey)
    }

    /// Clear stored API key (for logout/reset)
    static func clearStoredAPIKey() {
        KeychainHelper.shared.delete(forKey: apiKeyKeychainKey)
    }

    static var wsURL: String {
        switch Environment.current {
        case .development:
            if ProcessInfo.processInfo.environment["LYO_USE_LOCALHOST"] == "1" {
                return "ws://localhost:8000/ws"
            }
            return "wss://api.lyoai.app/ws"
        case .staging:
            return "wss://api.lyoai.app/ws"
        case .production:
            return "wss://api.lyoai.app/ws"
        }
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
