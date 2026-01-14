import SwiftUI
import Speech
import AVFoundation

// MARK: - Enhanced Lyo Avatar with Accessibility

struct AccessibleLyoAvatar: View {
    let onTap: () -> Void
    @Binding var lyoButtonFrame: CGRect

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @StateObject private var hapticManager = HapticManager.shared
    @EnvironmentObject var orchestrator: LyoOrchestrator

    @State private var isPressed = false
    @State private var isListening = false
    @State private var isBreathing = false
    @State private var isHovering = false
    @State private var shockwaveScale: CGFloat = 0.0
    @State private var shockwaveOpacity: Double = 0.0
    @State private var progress: Double = 0.65
    @State private var streakActive: Bool = true

    // Accessibility state
    @State private var isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
    @State private var prefersReducedMotion = UIAccessibility.isReduceMotionEnabled
    @State private var shouldUseHighContrast = UIAccessibility.isDarkerSystemColorsEnabled

    // Determine glow color based on context and progress
    var glowColor: Color {
        if let context = orchestrator.activeContext {
            switch context.complexity {
            case .simple:
                return Color(hex: "60A5FA") // Blue for simple
            case .moderate:
                return Color(hex: "A78BFA") // Purple for moderate
            case .complex:
                return Color(hex: "FF8C00") // Orange for complex
            }
        }

        if streakActive && progress >= 1.0 {
            return Color(hex: "FF8C00") // Gold/Orange for mastery
        } else if progress >= 0.5 {
            return Color(hex: "A78BFA") // Purple for progress
        } else {
            return Color(hex: "60A5FA") // Blue for beginning
        }
    }

    var accessibilityLabel: String {
        var label = "Lyo, your AI learning companion"

        if let context = orchestrator.activeContext {
            label += ", currently helping with \(context.topic)"
        }

        if isListening {
            label += ", listening to your voice"
        }

        return label
    }

    var accessibilityHint: String {
        if isVoiceOverRunning {
            return "Double tap to start conversation, or hold with VoiceOver to use voice input"
        } else {
            return "Tap to chat with Lyo, hold for voice input, or shake device for accessibility options"
        }
    }

    var body: some View {
        Button(action: {
            handleLyoInteraction()
        }) {
            ZStack {
                // 0. Particles (Background) - Reduced for motion sensitivity
                if !prefersReducedMotion {
                    MascotParticles(color: glowColor, reduced: isVoiceOverRunning)
                        .frame(width: 120, height: 120)
                }

                // 1. Shockwave Ring - Enhanced for accessibility
                Circle()
                    .stroke(
                        shouldUseHighContrast ? .white : glowColor,
                        lineWidth: shouldUseHighContrast ? 4 : 2
                    )
                    .frame(width: 70, height: 70)
                    .scaleEffect(shockwaveScale)
                    .opacity(shockwaveOpacity)

                // 2. Progressive Glow Field - Adjusted for accessibility
                if !prefersReducedMotion {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    glowColor.opacity(shouldUseHighContrast ? 0.8 : 0.6),
                                    glowColor.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(isBreathing ? 1.15 : 1.0)
                        .opacity(isBreathing ? 0.7 : 0.4)
                }

                // 3. Core Glow - High contrast support
                Circle()
                    .fill(
                        shouldUseHighContrast ?
                            .white.opacity(0.6) :
                            glowColor.opacity(0.4)
                    )
                    .frame(width: 75, height: 75)
                    .blur(radius: shouldUseHighContrast ? 8 : 12)
                    .scaleEffect(isBreathing && !prefersReducedMotion ? 1.05 : 0.95)

                // 4. Voice Input Indicator
                if isListening {
                    PulsingVoiceIndicator(color: glowColor)
                        .frame(width: 90, height: 90)
                }

                // 5. The Mascot Avatar
                Group {
                    if let avatarImage = UIImage(named: "LyoAvatar") {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        // Fallback icon
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 70, height: 70)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .shadow(
                    color: shouldUseHighContrast ? .black : glowColor.opacity(0.6),
                    radius: 10,
                    x: 0,
                    y: 5
                )
                // 3D Hover Effect - Disabled for reduced motion
                .offset(y: (isHovering && !prefersReducedMotion) ? -6 : 4)
                .rotation3DEffect(
                    .degrees((isHovering && !prefersReducedMotion) ? 5 : -5),
                    axis: (x: 10, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees((isHovering && !prefersReducedMotion) ? 3 : -3),
                    axis: (x: 0, y: 10, z: 0)
                )

                // 6. Context Indicator Badge
                if let context = orchestrator.activeContext {
                    ContextIndicatorBadge(context: context)
                        .offset(x: 25, y: -25)
                }

                // 7. Accessibility Focus Ring
                if isVoiceOverRunning {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .opacity(0.8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 90, height: 90)

        // MARK: - Accessibility Configuration
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits([.isButton])
        .accessibilityAction {
            handleLyoInteraction()
        }
        .accessibilityAction(named: "Start Voice Input") {
            startVoiceInput()
        }
        .accessibilityAction(named: "View Learning Context") {
            announceCurrentContext()
        }

        // MARK: - Gesture Handling
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    if !isListening {
                        hapticManager.heavy()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }

                    if !isListening {
                        startVoiceInput()
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isListening {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )

        // MARK: - Animation Setup
        .onAppear {
            setupAnimations()
            setupAccessibilityNotifications()
            updateFramePosition()
        }
        .onChange(of: UIAccessibility.isVoiceOverRunning) { _, newValue in
            isVoiceOverRunning = newValue
            if newValue {
                reduceAnimationsForAccessibility()
            }
        }
        .onChange(of: UIAccessibility.isReduceMotionEnabled) { _, newValue in
            prefersReducedMotion = newValue
            if newValue {
                reduceAnimationsForAccessibility()
            }
        }
        .onChange(of: UIAccessibility.isDarkerSystemColorsEnabled) { _, newValue in
            shouldUseHighContrast = newValue
        }

        // MARK: - Speech Recognition
        .onChange(of: speechRecognizer.isListening) { _, listening in
            isListening = listening
            if listening {
                announceVoiceInputStart()
            }
        }
        .onChange(of: speechRecognizer.transcript) { _, transcript in
            if !transcript.isEmpty && speechRecognizer.isFinished {
                handleVoiceInput(transcript)
            }
        }
    }

    // MARK: - Interaction Handlers

    private func handleLyoInteraction() {
        triggerShockwave()
        hapticManager.medium()

        // Announce action for VoiceOver users
        if isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Opening Lyo chat"
            )
        }

        // Provide multiple input options based on accessibility needs
        if UIAccessibility.isVoiceOverRunning {
            // For VoiceOver users, provide choice
            presentAccessibilityOptions()
        } else {
            // Standard tap interaction
            onTap()
        }
    }

    private func startVoiceInput() {
        guard speechRecognizer.canRecord else {
            announceVoiceInputError()
            return
        }

        hapticManager.light()

        if isListening {
            speechRecognizer.stopRecording()
            announceVoiceInputEnd()
        } else {
            speechRecognizer.startRecording()
            announceVoiceInputStart()
        }
    }

    private func handleVoiceInput(_ transcript: String) {
        guard !transcript.isEmpty else { return }

        hapticManager.success()

        Task {
            let response = await orchestrator.processUserMessage(transcript)

            // Speak the response for voice users
            speakResponse(response.primaryResponse)
        }
    }

    // MARK: - Accessibility Helpers

    private func presentAccessibilityOptions() {
        let alert = UIAlertController(
            title: "Lyo Interaction",
            message: "How would you like to interact with Lyo?",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Type Message", style: .default) { _ in
            onTap()
        })

        alert.addAction(UIAlertAction(title: "Voice Input", style: .default) { _ in
            startVoiceInput()
        })

        if let context = orchestrator.activeContext {
            alert.addAction(UIAlertAction(title: "Current Context: \(context.topic)", style: .default) { _ in
                announceCurrentContext()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Present alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    private func announceCurrentContext() {
        let announcement: String

        if let context = orchestrator.activeContext {
            announcement = "Currently learning about \(context.topic). Complexity level: \(context.complexity.rawValue). Content type: \(context.contentType.rawValue)."
        } else {
            announcement = "No active learning context. Ready to start a new conversation."
        }

        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }

    private func announceVoiceInputStart() {
        UIAccessibility.post(
            notification: .announcement,
            argument: "Voice input started. Speak your question or message to Lyo."
        )
    }

    private func announceVoiceInputEnd() {
        UIAccessibility.post(
            notification: .announcement,
            argument: "Voice input ended. Processing your message."
        )
    }

    private func announceVoiceInputError() {
        UIAccessibility.post(
            notification: .announcement,
            argument: "Voice input is not available. Please check microphone permissions."
        )
    }

    private func speakResponse(_ response: String) {
        let utterance = AVSpeechUtterance(string: response)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    // MARK: - Animation Management

    private func setupAnimations() {
        // Only setup animations if motion is not reduced
        guard !prefersReducedMotion else { return }

        // Breathing (Glow)
        withAnimation(
            Animation
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            isBreathing = true
        }

        // Hovering (Movement)
        withAnimation(
            Animation
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            isHovering = true
        }
    }

    private func reduceAnimationsForAccessibility() {
        if prefersReducedMotion || isVoiceOverRunning {
            withAnimation(.easeInOut(duration: 0.3)) {
                isBreathing = false
                isHovering = false
            }
        }
    }

    private func triggerShockwave() {
        // Reduced shockwave for accessibility
        shockwaveScale = 1.0
        shockwaveOpacity = shouldUseHighContrast ? 1.0 : 0.8

        let duration = prefersReducedMotion ? 0.2 : 0.5

        withAnimation(.easeOut(duration: duration)) {
            shockwaveScale = prefersReducedMotion ? 1.5 : 2.5
            shockwaveOpacity = 0.0
        }

        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            shockwaveScale = 1.0
        }
    }

    private func updateFramePosition() {
        DispatchQueue.main.async {
            // Update the frame binding for parent view
            // This would need to be connected to a GeometryReader in the parent
        }
    }

    // MARK: - Accessibility Notifications

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
            if prefersReducedMotion {
                reduceAnimationsForAccessibility()
            }
        }
    }
}

// MARK: - Supporting Views

struct PulsingVoiceIndicator: View {
    let color: Color
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .scaleEffect(scale)
            .opacity(2.0 - scale) // Inverse opacity for better effect
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: false)
                ) {
                    scale = 1.5
                }
            }
    }
}

struct ContextIndicatorBadge: View {
    let context: LearningContext

    var badgeColor: Color {
        switch context.contentType {
        case .course:
            return .blue
        case .quiz:
            return .orange
        case .video:
            return .purple
        case .conversation:
            return .green
        case .explainer:
            return .yellow
        }
    }

    var iconName: String {
        switch context.contentType {
        case .course:
            return "book.fill"
        case .quiz:
            return "questionmark.circle.fill"
        case .video:
            return "play.circle.fill"
        case .conversation:
            return "message.fill"
        case .explainer:
            return "lightbulb.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: 24, height: 24)

            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
        .accessibilityLabel("Current context: \(context.contentType.rawValue)")
    }
}

// MARK: - Speech Recognizer

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var isFinished = false

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()

    var canRecord: Bool {
        speechRecognizer?.isAvailable ?? false
    }

    func startRecording() {
        guard canRecord else { return }

        // Request permissions if needed
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.startRecognition()
                }
            }
        }
    }

    private func startRecognition() {
        do {
            // Audio session setup
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Recognition setup
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }

            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode

            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                var isFinal = false

                if let result = result {
                    DispatchQueue.main.async {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    isFinal = result.isFinal
                }

                if error != nil || isFinal {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)

                    self.recognitionRequest = nil
                    self.recognitionTask = nil

                    DispatchQueue.main.async {
                        self.isListening = false
                        self.isFinished = true
                    }
                }
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            isFinished = false
            transcript = ""

        } catch {
            print("Speech recognition error: \(error)")
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }
}
