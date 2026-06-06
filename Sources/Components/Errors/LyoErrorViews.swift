import SwiftUI
import AVFoundation

// MARK: - Lyo Error Components
// Using canonical LyoError from LyoError.swift


// MARK: - Lyo Action

// MARK: - Supporting Views


// MARK: - Lyo Error View

struct LyoErrorView: View {
    let error: LyoError
    let onDismiss: (() -> Void)?

    @State private var isVisible = false
    @State private var lyoAnimationPhase = 0.0
    @StateObject private var hapticManager = HapticManager.shared

    // Accessibility
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @State private var prefersReducedMotion = UIAccessibility.isReduceMotionEnabled

    var body: some View {
        ZStack {
            // Background blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissError()
                }

            // Main error content
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Animated Lyo avatar with emotion
                    LyoEmotionalAvatar(
                        emotion: error.emotion,
                        animationPhase: lyoAnimationPhase,
                        isAnimated: !prefersReducedMotion
                    )
                    .frame(width: 120, height: 120)
                    .accessibilityLabel("Lyo expressing \(error.emotion.rawValue) emotion")

                    // Error message content
                    VStack(spacing: 16) {
                        Text(error.lyoMessage)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text(error.actionableAdvice)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal)

                    // Suggested actions
                    VStack(spacing: 12) {
                        ForEach(error.suggestedActions) { action in
                            LyoActionButton(
                                action: action,
                                onTap: {
                                    hapticManager.light()
                                    action.handler()

                                    // Dismiss after action unless it's a retry
                                    if !["retry", "try_again", "try_voice_again"].contains(action.id) {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            dismissError()
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 60)
                }
            }

            // Dismiss button (top right)
            VStack {
                HStack {
                    Spacer()

                    Button(action: dismissError) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .accessibilityLabel("Dismiss error")
                    .accessibilityHint("Double tap to close this error message")
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                }

                Spacer()
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.8)
        .onAppear {
            setupAccessibilityNotifications()
            animateAppearance()
            announceForAccessibility()
        }
        .onChange(of: UIAccessibility.isVoiceOverRunning) { _, newValue in
            isVoiceOverRunning = newValue
        }
        .onChange(of: UIAccessibility.isReduceMotionEnabled) { _, newValue in
            prefersReducedMotion = newValue
        }
    }

    // MARK: - Animation & Interaction Methods

    private func animateAppearance() {
        hapticManager.medium()

        let duration = prefersReducedMotion ? 0.2 : 0.5

        withAnimation(.spring(response: duration, dampingFraction: 0.8)) {
            isVisible = true
        }

        // Start Lyo animation
        if !prefersReducedMotion {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                lyoAnimationPhase = 1.0
            }
        }
    }

    private func dismissError() {
        hapticManager.light()

        let duration = prefersReducedMotion ? 0.2 : 0.3

        withAnimation(.easeInOut(duration: duration)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            onDismiss?()
        }
    }

    private func announceForAccessibility() {
        guard isVoiceOverRunning else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let announcement = "\(error.lyoMessage) \(error.actionableAdvice)"
            UIAccessibility.post(
                notification: .announcement,
                argument: announcement
            )
        }
    }

    private func setupAccessibilityNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            prefersReducedMotion = UIAccessibility.isReduceMotionEnabled
        }
    }
}

// MARK: - Lyo Emotional Avatar

struct LyoEmotionalAvatar: View {
    let emotion: LyoEmotion
    let animationPhase: Double
    let isAnimated: Bool

    private var emotionColor: Color {
        switch emotion {
        case .friendly, .encouraging:
            return Color(hex: "10B981") // Green
        case .excited, .proud:
            return Color(hex: "F59E0B") // Orange
        case .thoughtful:
            return Color(hex: "6366F1") // Indigo
        case .apologetic:
            return Color(hex: "EF4444") // Red
        case .confused:
            return Color(hex: "8B5CF6") // Purple
        }
    }

    private var emotionExpression: String {
        switch emotion {
        case .friendly, .encouraging:
            return "😊"
        case .excited:
            return "🤩"
        case .thoughtful:
            return "🤔"
        case .apologetic:
            return "😅"
        case .confused:
            return "😕"
        case .proud:
            return "😌"
        }
    }

    var body: some View {
        ZStack {
            // Emotional glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            emotionColor.opacity(0.6),
                            emotionColor.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(isAnimated ? (1.0 + animationPhase * 0.2) : 1.0)
                .opacity(isAnimated ? (0.8 - animationPhase * 0.3) : 0.6)

            // Core avatar
            Circle()
                .fill(emotionColor.opacity(0.3))
                .frame(width: 120, height: 120)
                .blur(radius: 15)
                .scaleEffect(isAnimated ? (1.0 + animationPhase * 0.1) : 1.0)

            // Lyo character or fallback
            Group {
                if let avatarImage = UIImage(named: "LyoAvatar") {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                } else {
                    // Fallback with emotion
                    VStack(spacing: 4) {
                        Text(emotionExpression)
                            .font(.system(size: 40))

                        Text("Lyo")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            .shadow(color: emotionColor.opacity(0.6), radius: 20, x: 0, y: 10)
            .scaleEffect(isAnimated ? (1.0 + sin(animationPhase * .pi * 2) * 0.05) : 1.0)
            .rotation3DEffect(
                .degrees(isAnimated ? sin(animationPhase * .pi) * 5 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
        }
    }
}

// MARK: - Lyo Action Button

struct LyoActionButton: View {
    let action: LyoAction
    let onTap: () -> Void

    @State private var isPressed = false

    private var buttonColor: Color {
        switch action.style {
        case .primary:
            return Color(hex: "3B82F6") // Blue
        case .secondary:
            return Color(hex: "6B7280") // Gray
        case .tertiary:
            return .clear
        }
    }

    private var textColor: Color {
        switch action.style {
        case .primary, .secondary:
            return .white
        case .tertiary:
            return Color(hex: "3B82F6")
        }
    }

    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(action.title)
                    .font(.body.weight(.semibold))

                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                action.style == .tertiary ? Color(hex: "3B82F6") : .clear,
                                lineWidth: action.style == .tertiary ? 2 : 0
                            )
                    )
            )
            .foregroundColor(textColor)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .accessibilityLabel(action.accessibleLabel)
        .accessibilityHint(action.accessibleHint)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Error Manager

@MainActor
class LyoErrorManager: ObservableObject {
    static let shared = LyoErrorManager()

    @Published var currentError: LyoError?
    @Published var errorHistory: [LyoError] = []

    private init() {}

    func showError(_ error: LyoError) {
        HapticManager.shared.error()

        currentError = error
        errorHistory.append(error)

        // Limit error history
        if errorHistory.count > 10 {
            errorHistory.removeFirst()
        }

        // Auto-dismiss certain errors
        if case .rateLimitExceeded(let retryAfter) = error, let delay = retryAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.currentError?.id == error.id {
                    self.dismissError()
                }
            }
        }
    }

    func dismissError() {
        currentError = nil
    }

    func clearHistory() {
        errorHistory.removeAll()
    }
}

// MARK: - Error View Modifier

struct LyoErrorHandling: ViewModifier {
    @StateObject private var errorManager = LyoErrorManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if let error = errorManager.currentError {
                        LyoErrorView(
                            error: error,
                            onDismiss: {
                                errorManager.dismissError()
                            }
                        )
                        .zIndex(1000)
                    }
                }
            )
            .environmentObject(errorManager)
    }
}

extension View {
    func lyoErrorHandling() -> some View {
        modifier(LyoErrorHandling())
    }
}