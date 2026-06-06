//
//  HapticManager.swift
//  Lyo
//
//  Centralized haptic feedback manager for the app
//

import UIKit

/// Centralized haptic feedback manager
@MainActor
final class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    // MARK: - Feedback Generators
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // MARK: - Settings
    
    private var isEnabled: Bool {
        // Check user preference
        UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    
    private init() {
        // Set default value if not set
        if UserDefaults.standard.object(forKey: "hapticsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "hapticsEnabled")
        }
        
        prepareGenerators()
    }
    
    // MARK: - Prepare Generators
    
    private func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Impact Feedback
    
    /// Light tap feedback - for subtle interactions
    func playLightImpact() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
    }
    
    /// Medium tap feedback - for standard interactions
    func playMediumImpact() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
    }
    
    /// Heavy tap feedback - for significant actions
    func playHeavyImpact() {
        guard isEnabled else { return }
        heavyImpact.impactOccurred()
    }
    
    /// Soft feedback - for gentle confirmations
    func playSoftImpact() {
        guard isEnabled else { return }
        softImpact.impactOccurred()
    }
    
    /// Rigid feedback - for firm confirmations
    func playRigidImpact() {
        guard isEnabled else { return }
        rigidImpact.impactOccurred()
    }
    
    // MARK: - Selection Feedback
    
    /// Selection changed feedback - for picker/list selections
    func playSelection() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Notification Feedback
    
    /// Success feedback - for completed actions
    func playSuccess() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning feedback - for cautionary notifications
    func playWarning() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error feedback - for failed actions
    func playError() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Contextual Haptics
    
    /// Message sent haptic pattern
    func playMessageSent() {
        guard isEnabled else { return }
        playMediumImpact()
    }
    
    /// Message received haptic pattern
    func playMessageReceived() {
        guard isEnabled else { return }
        playSoftImpact()
    }
    
    /// Voice recording started
    func playRecordingStarted() {
        guard isEnabled else { return }
        playMediumImpact()
        // Double tap pattern
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playLightImpact()
        }
    }
    
    /// Voice recording stopped
    func playRecordingStopped() {
        guard isEnabled else { return }
        playRigidImpact()
    }
    
    /// Attachment added
    func playAttachmentAdded() {
        guard isEnabled else { return }
        playLightImpact()
    }
    
    /// Quiz answer selected
    func playQuizSelection() {
        guard isEnabled else { return }
        playSelection()
    }
    
    /// Quiz answer correct
    func playQuizCorrect() {
        guard isEnabled else { return }
        playSuccess()
    }
    
    /// Quiz answer incorrect
    func playQuizIncorrect() {
        guard isEnabled else { return }
        playError()
    }
    
    /// Course completed celebration
    func playCourseCompleted() {
        guard isEnabled else { return }
        // Celebration pattern
        playHeavyImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.playMediumImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.playSuccess()
        }
    }
    
    /// Button tap - standard button feedback
    func playButtonTap() {
        guard isEnabled else { return }
        playLightImpact()
    }
    
    /// Long press activated
    func playLongPress() {
        guard isEnabled else { return }
        playMediumImpact()
    }
    
    /// Swipe action
    func playSwipe() {
        guard isEnabled else { return }
        playSoftImpact()
    }
    
    /// Pull to refresh
    func playPullToRefresh() {
        guard isEnabled else { return }
        playMediumImpact()
    }
    
    /// Achievement unlocked
    func playAchievementUnlocked() {
        guard isEnabled else { return }
        // Triple burst pattern
        playHeavyImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playMediumImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playLightImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.playSuccess()
        }
    }
    
    /// Level up celebration
    func playLevelUp() {
        guard isEnabled else { return }
        // Ascending pattern
        playSoftImpact()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playLightImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playMediumImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.playHeavyImpact()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.playSuccess()
        }
    }
    
    // MARK: - Custom Patterns
    
    /// Play a custom intensity impact
    func playCustomImpact(intensity: CGFloat) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: intensity)
    }
    
    /// Play a series of impacts with timing
    func playPattern(_ pattern: [(style: UIImpactFeedbackGenerator.FeedbackStyle, delay: TimeInterval)]) {
        guard isEnabled else { return }
        
        var cumulativeDelay: TimeInterval = 0
        
        for item in pattern {
            cumulativeDelay += item.delay
            DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) {
                let generator = UIImpactFeedbackGenerator(style: item.style)
                generator.impactOccurred()
            }
        }
    }
    
    // MARK: - Settings
    
    /// Enable or disable haptics
    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "hapticsEnabled")
    }
    
    /// Check if haptics are enabled
    func getEnabled() -> Bool {
        return isEnabled
    }
    // MARK: - Legacy Aliases (Legacy support for simpler API)
    
    func light() { playLightImpact() }
    func medium() { playMediumImpact() }
    func heavy() { playHeavyImpact() }
    func soft() { playSoftImpact() }
    func rigid() { playRigidImpact() }
    func selection() { playSelection() }
    func success() { playSuccess() }
    func warning() { playWarning() }
    func error() { playError() }
}

// MARK: - SwiftUI View Extension

import SwiftUI

extension View {
    func hapticFeedback(_ style: HapticFeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    switch style {
                    case .light:
                        HapticManager.shared.light()
                    case .medium:
                        HapticManager.shared.medium()
                    case .heavy:
                        HapticManager.shared.heavy()
                    case .soft:
                        HapticManager.shared.soft()
                    case .rigid:
                        HapticManager.shared.rigid()
                    case .selection:
                        HapticManager.shared.selection()
                    case .success:
                        HapticManager.shared.success()
                    case .warning:
                        HapticManager.shared.warning()
                    case .error:
                        HapticManager.shared.error()
                    }
                }
        )
    }
}

enum HapticFeedbackStyle {
    case light, medium, heavy, soft, rigid
    case selection
    case success, warning, error
}
