//
//  A2UICapabilityNegotiator.swift
//  Lyo
//
//  Handles capability negotiation between Client (App) and Server (AI)
//  Ensures the AI only sends UI components the app can render.
//

import Foundation
import UIKit

// MARK: - Capability Negotiator

struct A2UICapabilityNegotiator {
    
    // MARK: - Current Capabilities
    
    /// Generates the capability header string to send to backend
    static func generateClientCapabilities() -> String {
        let caps = ClientCapabilities(
            version: "2.0.0",
            supportedCategories: A2UIElementCategory.allCases.map { $0.rawValue },
            supportedComponents: A2UIElementType.allCases.map { $0.rawValue },
            features: [
                "streaming": true,
                "interactive": true,
                "audio_input": true,
                "camera_input": true,
                "haptics": true,
                "dark_mode": true
            ],
            screen: ScreenInfo(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height,
                scale: UIScreen.main.scale,
                dynamicTypeSize: UIApplication.shared.preferredContentSizeCategory.rawValue
            )
        )
        
        do {
            let data = try JSONEncoder().encode(caps)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to encode client capabilities: \(error)")
            return ""
        }
    }
    
    // MARK: - Models
    
    private struct ClientCapabilities: Encodable {
        let version: String
        let supportedCategories: [String]
        let supportedComponents: [String]
        let features: [String: Bool]
        let screen: ScreenInfo
    }
    
    private struct ScreenInfo: Encodable {
        let width: CGFloat
        let height: CGFloat
        let scale: CGFloat
        let dynamicTypeSize: String
    }
}
