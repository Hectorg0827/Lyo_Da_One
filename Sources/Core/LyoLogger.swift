import os
import Foundation

// MARK: - Unified Logging for Lyo
//
// Replaces raw `print()` with structured `os.Logger` so logs are:
//   • Categorised & filterable in Console.app / Instruments
//   • Automatically redacted for privacy in Release builds
//   • Zero-cost when a log level is disabled
//
// Usage:
//   Log.net.info("Request succeeded")
//   Log.ai.error("Stream failed: \(error)")
//   Log.auth.debug("Token refreshed")
//   Log.ui.warning("Missing thumbnail for course \(id)")

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lyo.app"

    // MARK: - Categories

    /// Networking, API calls, SSE streams
    static let net = Logger(subsystem: subsystem, category: "network")

    /// AI services — BackendAIService, CourseGeneration, OpenAI
    static let ai = Logger(subsystem: subsystem, category: "ai")

    /// Authentication, tokens, sessions
    static let auth = Logger(subsystem: subsystem, category: "auth")

    /// UI lifecycle, navigation, view events
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Course generation pipeline
    static let course = Logger(subsystem: subsystem, category: "course")

    /// Classroom & lesson playback
    static let classroom = Logger(subsystem: subsystem, category: "classroom")

    /// Community, social, feed
    static let social = Logger(subsystem: subsystem, category: "social")

    /// Push notifications
    static let push = Logger(subsystem: subsystem, category: "push")

    /// Data persistence, caching, UserDefaults
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Audio, voice, TTS, STT
    static let audio = Logger(subsystem: subsystem, category: "audio")

    /// Monetization, subscriptions, StoreKit
    static let monetization = Logger(subsystem: subsystem, category: "monetization")

    /// App lifecycle, config, feature flags
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Deep links, URL handling
    static let deeplink = Logger(subsystem: subsystem, category: "deeplink")

    /// Discovery, search, recommendations
    static let discover = Logger(subsystem: subsystem, category: "discover")

    /// Camera, media capture
    static let media = Logger(subsystem: subsystem, category: "media")

    /// Gamification, XP, streaks
    static let gamification = Logger(subsystem: subsystem, category: "gamification")

    /// General / uncategorised (use sparingly)
    static let general = Logger(subsystem: subsystem, category: "general")
}
