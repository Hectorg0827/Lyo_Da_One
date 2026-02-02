import Foundation
import Combine
import SwiftUI

/// Bridge between Voice Input and A2UI Actions
@MainActor
class A2UIVoiceController: ObservableObject {
    static let shared = A2UIVoiceController()
    
    // Dependencies
    private let voiceService = VoiceInputService.shared
    
    // State
    @Published var listeningForCommands = false
    private var cancellables = Set<AnyCancellable>()
    private var currentRootComponent: A2UIComponent?
    private var actionHandler: ((A2UIAction, A2UIComponent) -> Void)?
    
    private init() {
        setupVoiceListeners()
    }
    
    /// Register the active UI tree for voice control
    func registerActiveUI(component: A2UIComponent, onAction: @escaping (A2UIAction, A2UIComponent) -> Void) {
        self.currentRootComponent = component
        self.actionHandler = onAction
    }
    
    private func setupVoiceListeners() {
        // Listen for transcripts from VoiceInputService
        voiceService.$transcript
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard !text.isEmpty else { return }
                Task { @MainActor in
                    self?.processVoiceCommand(text)
                }
            }
            .store(in: &cancellables)
    }
    
    private func processVoiceCommand(_ text: String) {
        guard let root = currentRootComponent else { return }
        
        let command = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🗣️ A2UI Processing Command: '\(command)'")
        
        // Find matching action in the UI tree
        if let match = findActionForCommand(command, in: root) {
            print("✅ Executing Voice Action: \(match.action.id)")
            
            // Execute the action
            // Trigger haptic feedback
            #if os(iOS)
            HapticManager.shared.playSuccess()
            #endif
            
            actionHandler?(match.action, match.component)
        }
    }
    
    /// Recursively find a component that matches the voice command
    private func findActionForCommand(_ command: String, in component: A2UIComponent) -> (action: A2UIAction, component: A2UIComponent)? {
        // 1. Check component's actions array for matching voice commands or tap actions
        if let actions = component.actions {
            for action in actions {
                // Direct voice command match
                if action.trigger == .voiceCommand {
                    return (action: action, component: component)
                }
                
                // Check if it's a button with text that matches the command
                if component.type == .button,
                   let label = component.props.text?.lowercased(),
                   (command.contains(label) || label.contains(command)),
                   action.trigger == .tap {
                    return (action: action, component: component)
                }
                
                // Check semantic matching (next, back, submit)
                let actionId = action.id.lowercased()
                if (command == "next" && actionId.contains("next")) ||
                   (command == "back" && actionId.contains("prev")) ||
                   (command == "submit" && actionId.contains("submit")) {
                    return (action: action, component: component)
                }
            }
        }
        
        // 2. Recurse children
        if let children = component.children {
            for child in children {
                if let match = findActionForCommand(command, in: child) {
                    return match
                }
            }
        }
        
        return nil
    }
}
