import SwiftUI
import AVKit
import WebKit

// MARK: - Advanced A2UI Component Renderers
// NOTE: This file contains advanced component renderers that are not yet fully integrated
// with the main UIComponentType enum. These are placeholder implementations.

@available(iOS 15.0, *)
struct AdvancedA2UIRenderer: View {
    let component: DynamicComponent

    var body: some View {
        // Placeholder - advanced components not yet fully implemented
        Text("Advanced component: \(component.type.rawValue)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Video Player Payload (Simplified)

struct VideoPlayerPayload: Codable {
    let videoUrl: String
    let title: String?
    
    enum CodingKeys: String, CodingKey {
        case videoUrl = "video_url"
        case title
    }
}

// MARK: - Code Sandbox Payload (Simplified)

struct CodeSandboxPayload: Codable {
    let language: String
    let title: String
    let initialCode: String
    
    enum CodingKeys: String, CodingKey {
        case language, title
        case initialCode = "initial_code"
    }
}

// MARK: - Collaboration Space Payload (Simplified)

struct CollaborationSpacePayload: Codable {
    let sessionId: String
    let title: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
    }
}

// MARK: - Whiteboard Payload (Simplified)

struct WhiteboardPayload: Codable {
    let width: Int
    let height: Int
    let backgroundColor: String
    
    enum CodingKeys: String, CodingKey {
        case width, height
        case backgroundColor = "background_color"
    }
}

// MARK: - Preview

// Preview disabled - DynamicComponent requires Decoder-based initialization
// #Preview {
//     AdvancedA2UIRenderer(...)
// }

