import Foundation
import os

/// Centralized logging system for Lyo
struct Log {
    // MARK: - Logger Categories
    static let ui = Logger(subsystem: "com.lyo.app", category: "UI")
    static let media = Logger(subsystem: "com.lyo.app", category: "Media")
    static let network = Logger(subsystem: "com.lyo.app", category: "Network")
    static let auth = Logger(subsystem: "com.lyo.app", category: "Auth")
    static let ai = Logger(subsystem: "com.lyo.app", category: "AI")
    static let camera = Logger(subsystem: "com.lyo.app", category: "Camera")
    static let general = Logger(subsystem: "com.lyo.app", category: "General")
}