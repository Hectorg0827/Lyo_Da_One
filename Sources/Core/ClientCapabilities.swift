//
//  ClientCapabilities.swift
//  Lyo
//
//  Part of the Unbreakable Protocol - declares what UI components this client supports
//  so the backend can gracefully degrade for new features.
//
//  Created by Lyo AI on 2026-02-01.
//

import Foundation
import UIKit

/// Declares UI capabilities of this iOS client version.
/// Sent with every API request so backend can filter unsupported components.
class ClientCapabilities {
    
    // MARK: - Singleton
    static let shared = ClientCapabilities()
    
    // MARK: - Version Info
    
    /// Client version (matches app version)
    let version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    
    /// Build number
    let build: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    /// Protocol version - increment when capability format changes
    let protocolVersion = "1.0"
    
    // MARK: - Supported Components
    
    /// All A2UI component types this client can render.
    /// When adding new components, add them here so backend knows we support them.
    let supportedComponents: [String] = [
        // Layout
        "vstack",
        "hstack",
        "zstack",
        "scroll_view",
        "lazy_vstack",
        "lazy_hstack",
        "grid",
        "spacer",
        "divider",
        
        // Typography
        "text",
        "heading",
        "label",
        "markdown",
        "attributed_text",
        
        // Interactive
        "button",
        "link",
        "text_field",
        "text_editor",
        "toggle",
        "slider",
        "picker",
        "stepper",
        
        // Media
        "image",
        "async_image",
        "video_player",
        "audio_player",
        "lottie_animation",
        
        // Cards & Containers
        "card",
        "section",
        "group",
        "disclosure_group",
        "navigation_link",
        
        // Educational
        "quiz_mcq",
        "quiz_true_false",
        "quiz_fill_blank",
        "flashcard",
        "flashcard_deck",
        "code_block",
        "code_playground",
        "diagram",
        "chart",
        
        // Feedback
        "progress_bar",
        "activity_indicator",
        "alert",
        "toast",
        "badge",
        
        // Navigation
        "tab_view",
        "navigation_stack",
        "sheet",
        "full_screen_cover",
    ]
    
    // MARK: - Feature Flags
    
    /// Additional features this client supports
    let features: [String: Bool] = [
        "dark_mode": true,
        "haptic_feedback": true,
        "offline_mode": true,
        "streaming_response": true,
        "voice_input": true,
        "ar_content": false,  // Not yet implemented
        "vr_content": false,  // Not yet implemented
    ]
    
    // MARK: - JSON Encoding
    
    /// Converts capabilities to JSON string for HTTP header
    func toJSON() -> String {
        let dict: [String: Any] = [
            "version": version,
            "build": build,
            "protocol_version": protocolVersion,
            "platform": "ios",
            "os_version": UIDevice.current.systemVersion,
            "device": UIDevice.current.model,
            "components": supportedComponents,
            "features": features
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        
        // Fallback to minimal header
        return "{\"version\":\"\(version)\",\"components\":[]}"
    }
    
    /// Returns just the version header value
    var versionHeader: String {
        return "\(version)+\(build)"
    }
    
    /// Returns a compact component list for header (semicolon-separated)
    var componentsHeader: String {
        return supportedComponents.joined(separator: ";")
    }
    
    // MARK: - Check Capability
    
    /// Check if this client supports a given component type
    func supports(_ componentType: String) -> Bool {
        return supportedComponents.contains(componentType.lowercased())
    }
    
    /// Check if a feature is enabled
    func hasFeature(_ feature: String) -> Bool {
        return features[feature] ?? false
    }
    
    // MARK: - Init
    
    private init() {
        // Private init for singleton
    }
}

// MARK: - UIDevice Extension for Platform Detection

extension ClientCapabilities {
    /// Returns device family for analytics
    var deviceFamily: String {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        case .mac: return "Mac"
        case .tv: return "AppleTV"
        case .vision: return "VisionPro"
        default: return "Unknown"
        }
    }
}
