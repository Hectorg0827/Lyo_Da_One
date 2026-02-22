import Foundation

/// Manages A2UI capabilities for the client
class CapabilityManager {
    static let shared = CapabilityManager()
    
    private init() {}
    
    /// Current supported capabilities
    var capabilities: [String] {
        return [
            "a2ui_v1",
            "voice_input",
            "camera_capture",
            "quiz_adaptive",
            "study_planning"
            // Add more capabilities as they are implemented
        ]
    }
    
    /// User agent string with capabilities
    var userAgent: String {
        let caps = capabilities.joined(separator: ",")
        return "LyoApp/1.0 (iOS; Capabilities: [\(caps)])"
    }
    
    /// Check if a specific capability is supported
    func supports(_ capability: String) -> Bool {
        return capabilities.contains(capability)
    }
}
