import UIKit

/// Centralized haptic feedback manager for Lyo Classroom.
/// Synchronizes haptics to visual and audio moments per Master Context.
@MainActor
public class LyoHapticManager {
    public static let shared = LyoHapticManager()
    
    // Pre-warmed generators
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-warming makes the hardware responsive immediately
        mediumImpact.prepare()
        lightImpact.prepare()
        softImpact.prepare()
        notification.prepare()
    }
    
    /// Medium impact haptic on every card arrival.
    public func playCardArrival() {
        mediumImpact.impactOccurred()
    }
    
    /// Light impact haptic for each character in kinetic typography reveals.
    public func playTypingCharacter() {
        lightImpact.impactOccurred(intensity: 0.6)
    }
    
    /// Success notification haptic on correct quiz answers.
    public func playQuizSuccess() {
        notification.notificationOccurred(.success)
    }
    
    /// Soft impact haptic when the Voice Orb transitions states.
    public func playOrbStateChange() {
        softImpact.impactOccurred()
    }
}
