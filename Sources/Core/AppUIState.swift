import Foundation
import SwiftUI
import Combine

// MARK: - App Tab Enum
/// Represents the main navigation tabs in the app
enum AppTab: String, CaseIterable {
    case focus = "focus"
    case discover = "discover"
    case campus = "campus"
    case collab = "collab"
    case profile = "profile" // Added for navigation
    
    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .discover: return "Clips" // Updated name
        case .campus: return "Community" // Updated name
        case .collab: return "Collab"
        case .profile: return "Profile"
        }
    }
    
    var aiModeLabel: String {
        switch self {
        case .focus: return "Home AI"
        case .discover: return "Clips AI"
        case .campus: return "Community AI"
        case .collab: return "Collab AI"
        case .profile: return "Profile AI"
        }
    }
}

// MARK: - App UI State
/// Global UI state for tracking app-wide context like current tab, tutor mode, and collab room
final class AppUIState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently selected tab
    @Published var currentTab: AppTab = .focus
    
    /// ID of the current collaboration room (nil if not in a collab room)
    @Published var currentCollabRoomId: String? = nil
    
    /// Whether Tutor Mode is currently active (Phase 1)
    @Published var isTutorActive: Bool = false
    
    /// Whether the Lio chat sheet is presented
    @Published var isLioChatPresented = false
    @Published var isStackPanelPresented = false
    @Published var isCreatingEvent = false // Triggers event creation in CampusView
    
    /// Context hint for Ask Lio buttons (set before presenting LioChatSheet)
    @Published var lioContextHint: String? = nil
    
    /// Course to display in detail sheet (set by AI chat when course is created)
    @Published var courseToDisplay: ContentItem? = nil
    @Published var showCourseDetail = false
    
    /// Chat Session to load when opening LioChatSheet (for history navigation)
    /// Type is Any? because ChatSession is only available in iOS 17+
    @Published var chatSessionToLoad: Any? = nil
    
    // MARK: - Computed Properties
    
    /// The AI mode based on current tab
    var currentAIMode: String {
        if currentCollabRoomId != nil {
            return "collab"
        }
        return currentTab.rawValue
    }
    
    /// Context dictionary to send with AI requests
    var currentContext: [String: Any]? {
        var context: [String: Any] = [:]
        
        if let roomId = currentCollabRoomId {
            context["room_id"] = roomId
        }
        
        // Add more context as needed (location for campus, etc.)
        
        return context.isEmpty ? nil : context
    }
    
    // MARK: - Methods
    
    /// Enter a collaboration room
    func enterCollabRoom(roomId: String) {
        currentCollabRoomId = roomId
    }
    
    /// Leave the current collaboration room
    func leaveCollabRoom() {
        currentCollabRoomId = nil
    }
    
    /// Set tutor mode state
    func setTutorActive(_ active: Bool) {
        isTutorActive = active
    }
}
