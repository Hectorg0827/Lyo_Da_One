import SwiftUI

// MARK: - Onboarding Overlay View

struct LyoOnboardingOverlay: View {
    @StateObject private var onboardingManager = LyoOnboardingManager.shared
    @State private var isVisible = false
    @State private var animationPhase: Double = 0

    // Accessibility
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @State private var prefersReducedMotion = UIAccessibility.isReduceMotionEnabled

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)

            // Main content
            if let currentStep = onboardingManager.currentOnboardingStep {
                OnboardingStepView(
                    step: currentStep,
                    animationPhase: animationPhase,
                    onComplete: {
                        onboardingManager.completeCurrentStep()
                    },
                    onSkip: {
                        onboardingManager.skipCurrentStep()
                    },
                    onDismiss: {
                        onboardingManager.dismissOnboarding()
                    }
                )
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.8)
                .offset(y: isVisible ? 0 : 50)
            }

            // Feature unlock celebration
            if let featureUnlock = onboardingManager.pendingFeatureUnlock {
                FeatureUnlockCelebration(
                    feature: featureUnlock,
                    onDismiss: {
                        onboardingManager.pendingFeatureUnlock = nil
                    }
                )
                .zIndex(1)
            }

            // Contextual hints
            VStack {
                Spacer()

                ForEach(onboardingManager.activeHints) { hint in
                    ContextualHintView(
                        hint: hint,
                        onDismiss: {
                            onboardingManager.dismissHint(hint.id)
                        },
                        onAction: {
                            handleHintAction(hint.action)
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 100) // Space for tab bar
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: onboardingManager.activeHints.count)
        .onReceive(onboardingManager.$showOnboardingOverlay) { showOverlay in
            updateVisibility(showOverlay)
        }
        .onReceive(onboardingManager.$currentOnboardingStep) { step in
            if step != nil {
                updateVisibility(true)
            }
        }
        .onChange(of: UIAccessibility.isVoiceOverRunning) { _, newValue in
            isVoiceOverRunning = newValue
        }
        .onChange(of: UIAccessibility.isReduceMotionEnabled) { _, newValue in
            prefersReducedMotion = newValue
            if newValue {
                // Disable animations for accessibility
                animationPhase = 0
            }
        }
        .onAppear {
            if !prefersReducedMotion {
                startAnimations()
            }
        }
    }

    // MARK: - Helper Methods

    private func updateVisibility(_ shouldShow: Bool) {
        let duration = prefersReducedMotion ? 0.2 : 0.5

        withAnimation(.spring(response: duration, dampingFraction: 0.8)) {
            isVisible = shouldShow
        }

        if shouldShow && isVoiceOverRunning {
            announceOnboardingStep()
        }
    }

    private func startAnimations() {
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            animationPhase = 1.0
        }
    }

    private func announceOnboardingStep() {
        guard let currentStep = onboardingManager.currentOnboardingStep else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: "\(currentStep.title). \(currentStep.description)"
            )
        }
    }

    private func handleHintAction(_ action: String?) {
        guard let action = action else { return }

        switch action {
        case "enable_voice":
            // Trigger voice input tutorial or permission request
            NotificationCenter.default.post(name: NSNotification.Name("ShowVoiceInputTutorial"), object: nil)

        case "create_course":
            // Navigate to course creation
            NotificationCenter.default.post(name: NSNotification.Name("TriggerCourseCreation"), object: nil)

        case "explore_discover":
            // Switch to discover tab
            NotificationCenter.default.post(
                name: NSNotification.Name("LyoNavigation"),
                object: nil,
                userInfo: ["destination": "discover"]
            )

        case "show_course_features":
            // Show course features explanation
            onboardingManager.showContextualHint(
                ContextualHint(
                    title: "Course Features",
                    description: "Say things like 'Teach me calculus' or 'Create a Python course' and I'll build complete learning experiences for you!",
                    icon: "book.fill",
                    action: nil,
                    priority: 1
                ),
                condition: .onlyOnce
            )

        default:
            break
        }
    }
}

// MARK: - Individual Step View

struct OnboardingStepView: View {
    let step: OnboardingStep
    let animationPhase: Double
    let onComplete: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @State private var isPressed = false
    @State private var showActions = false

    // Accessibility
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @State private var prefersReducedMotion = UIAccessibility.isReduceMotionEnabled

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "6366F1").opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(prefersReducedMotion ? 1.0 : (1.0 + animationPhase * 0.1))

                Image(systemName: step.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 10)
                    .scaleEffect(prefersReducedMotion ? 1.0 : (1.0 + sin(animationPhase * .pi * 2) * 0.05))
            }
            .accessibilityHidden(true) // Decorative

            // Content
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(step.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Actions
            VStack(spacing: 16) {
                // Primary Action
                OnboardingActionButton(
                    title: actionTitle(for: step.action),
                    icon: actionIcon(for: step.action),
                    style: .primary,
                    onTap: {
                        HapticManager.shared.success()
                        handleStepAction(step.action)
                        onComplete()
                    }
                )

                // Secondary Actions
                HStack(spacing: 20) {
                    OnboardingActionButton(
                        title: "Skip",
                        icon: "arrow.right",
                        style: .secondary,
                        onTap: {
                            HapticManager.shared.light()
                            onSkip()
                        }
                    )

                    if step.priority > 3 {
                        OnboardingActionButton(
                            title: "Dismiss",
                            icon: "xmark",
                            style: .tertiary,
                            onTap: {
                                HapticManager.shared.light()
                                onDismiss()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .opacity(showActions ? 1 : 0)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showActions = true
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func actionTitle(for action: OnboardingStep.OnboardingAction?) -> String {
        guard let action = action else { return "Got it!" }

        switch action {
        case .tapLyo:
            return "Start Chatting!"
        case .enableVoice:
            return "Try Voice Input"
        case .createCourse:
            return "Create a Course"
        case .exploreDiscover:
            return "Explore Content"
        case .joinCommunity:
            return "Join Community"
        case .customizeProfile:
            return "Customize Profile"
        }
    }

    private func actionIcon(for action: OnboardingStep.OnboardingAction?) -> String {
        guard let action = action else { return "checkmark" }

        switch action {
        case .tapLyo:
            return "message.fill"
        case .enableVoice:
            return "mic.fill"
        case .createCourse:
            return "book.fill"
        case .exploreDiscover:
            return "play.rectangle.fill"
        case .joinCommunity:
            return "person.3.fill"
        case .customizeProfile:
            return "person.circle.fill"
        }
    }

    private func handleStepAction(_ action: OnboardingStep.OnboardingAction?) {
        guard let action = action else { return }

        switch action {
        case .tapLyo:
            // Open Lyo chat
            NotificationCenter.default.post(name: NSNotification.Name("TriggerLioChat"), object: nil)

        case .enableVoice:
            // Request microphone permission and show voice tutorial
            NotificationCenter.default.post(name: NSNotification.Name("EnableVoiceInput"), object: nil)
            LyoOnboardingManager.shared.trackVoiceInputUsed()

        case .createCourse:
            // Open course creation flow
            NotificationCenter.default.post(name: NSNotification.Name("TriggerCourseCreation"), object: nil)

        case .exploreDiscover:
            // Navigate to discover tab
            NotificationCenter.default.post(
                name: NSNotification.Name("LyoNavigation"),
                object: nil,
                userInfo: ["destination": "discover"]
            )

        case .joinCommunity:
            // Navigate to community tab
            NotificationCenter.default.post(
                name: NSNotification.Name("LyoNavigation"),
                object: nil,
                userInfo: ["destination": "community"]
            )

        case .customizeProfile:
            // Navigate to profile tab
            NotificationCenter.default.post(
                name: NSNotification.Name("LyoNavigation"),
                object: nil,
                userInfo: ["destination": "profile"]
            )
        }
    }
}

// MARK: - Onboarding Action Button

struct OnboardingActionButton: View {
    let title: String
    let icon: String
    let style: Style
    let onTap: () -> Void

    @State private var isPressed = false

    enum Style {
        case primary, secondary, tertiary
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color(hex: "6366F1")
        case .secondary:
            return .clear
        case .tertiary:
            return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .white
        case .tertiary:
            return .white.opacity(0.6)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return .clear
        case .secondary:
            return .white.opacity(0.3)
        case .tertiary:
            return .clear
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(.body.weight(.semibold))

                if style == .primary {
                    Spacer()
                }
            }
            .padding(.vertical, style == .primary ? 18 : 12)
            .padding(.horizontal, style == .primary ? 24 : 16)
            .background(
                RoundedRectangle(cornerRadius: style == .primary ? 16 : 12)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: style == .primary ? 16 : 12)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .foregroundColor(foregroundColor)
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
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
    }
}

// MARK: - Feature Unlock Celebration

struct FeatureUnlockCelebration: View {
    let feature: FeatureDisclosure
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var celebrationScale: CGFloat = 0.5
    @State private var confettiOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(.black.opacity(0.3))
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Celebration Content
            VStack(spacing: 24) {
                // Celebration Animation
                ZStack {
                    if feature.announcement.celebrationStyle == .confetti {
                        ConfettiView()
                            .opacity(confettiOpacity)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: "FFD700").opacity(glowOpacity * 0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)

                    Image(systemName: feature.announcement.icon)
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundColor(Color(hex: "FFD700"))
                        .scaleEffect(celebrationScale)
                }
                .frame(width: 160, height: 160)

                // Content
                VStack(spacing: 16) {
                    Text(feature.announcement.title)
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(feature.announcement.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Action
                OnboardingActionButton(
                    title: "Awesome!",
                    icon: "star.fill",
                    style: .primary,
                    onTap: {
                        dismiss()
                    }
                )
                .padding(.horizontal, 40)
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
        }
        .onAppear {
            startCelebration()
            announceFeatureUnlock()
        }
    }

    private func startCelebration() {
        HapticManager.shared.success()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isVisible = true
        }

        withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
            celebrationScale = 1.2
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                celebrationScale = 1.0
            }
        }

        // Style-specific animations
        switch feature.announcement.celebrationStyle {
        case .confetti:
            withAnimation(.easeInOut(duration: 2.0)) {
                confettiOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 1.0)) {
                    confettiOpacity = 0.0
                }
            }

        case .glow:
            withAnimation(.easeInOut(duration: 1.0).repeatCount(3, autoreverses: true)) {
                glowOpacity = 1.0
            }

        case .pulse:
            withAnimation(.easeInOut(duration: 0.5).repeatCount(6, autoreverses: true)) {
                celebrationScale = 1.1
            }

        case .bounce:
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10).repeatCount(3)) {
                celebrationScale = 1.3
            }
        }

        // Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    private func announceFeatureUnlock() {
        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "\(feature.announcement.title) \(feature.announcement.description)"
                )
            }
        }
    }
}

// MARK: - Contextual Hint View

struct ContextualHintView: View {
    let hint: ContextualHint
    let onDismiss: () -> Void
    let onAction: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: hint.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "6366F1"))

            VStack(alignment: .leading, spacing: 4) {
                Text(hint.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)

                Text(hint.description)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            if hint.action != nil {
                Button(action: onAction) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hint.title). \(hint.description)")
        .accessibilityHint(hint.action != nil ? "Double tap to take action" : "Swipe to dismiss")
    }
}

// MARK: - Confetti Effect

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var velocity: CGPoint
        var color: Color
        var rotation: Double
        var scale: CGFloat
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.x,
                        y: particle.y,
                        width: 6 * particle.scale,
                        height: 6 * particle.scale
                    )

                    context.rotate(by: .degrees(particle.rotation))
                    context.fill(
                        RoundedRectangle(cornerRadius: 1).path(in: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
    }

    private func generateParticles() {
        let colors: [Color] = [
            Color(hex: "FFD700"),
            Color(hex: "FF6B6B"),
            Color(hex: "4ECDC4"),
            Color(hex: "45B7D1"),
            Color(hex: "96CEB4")
        ]

        for _ in 0..<50 {
            particles.append(ConfettiParticle(
                x: CGFloat.random(in: 0...400),
                y: -20,
                velocity: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: 2...5)
                ),
                color: colors.randomElement() ?? .yellow,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5)
            ))
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateParticles()
        }
    }

    private func updateParticles() {
        for i in particles.indices {
            particles[i].x += particles[i].velocity.x
            particles[i].y += particles[i].velocity.y
            particles[i].rotation += 5
            particles[i].velocity.y += 0.1 // gravity
        }

        // Remove particles that are off-screen
        particles.removeAll { $0.y > 1000 }
    }
}

// MARK: - View Modifier

struct OnboardingViewModifier: ViewModifier {
    @StateObject private var onboardingManager = LyoOnboardingManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if onboardingManager.showOnboardingOverlay || onboardingManager.currentOnboardingStep != nil || !onboardingManager.activeHints.isEmpty || onboardingManager.pendingFeatureUnlock != nil {
                        LyoOnboardingOverlay()
                            .zIndex(999)
                    }
                }
            )
            .environmentObject(onboardingManager)
    }
}

extension View {
    func lyoOnboarding() -> some View {
        modifier(OnboardingViewModifier())
    }
}