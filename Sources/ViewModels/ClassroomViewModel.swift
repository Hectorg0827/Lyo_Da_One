import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
class ClassroomViewModel: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var session: ClassroomSession?
    @Published var currentModuleIndex: Int = 0
    @Published var currentSlideIndex: Int = 0
    @Published var state: ClassroomState = .loading
    @Published var settings: ClassroomSettings = ClassroomSettings()
    @Published var controlsVisible: Bool = false
    @Published var showModuleGrid: Bool = false
    @Published var currentQuickCheck: QuickCheck?
    @Published var showReteach: Bool = false
    @Published var reteachContent: ReteachContent?
    @Published var errorMessage: String?
    
    // TTS State
    @Published var isNarrating: Bool = false
    @Published var narrationProgress: Double = 0.0
    @Published var currentWordRange: NSRange?
    
    // Progress
    @Published var slideProgress: Double = 0.0
    @Published var moduleProgress: Double = 0.0
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var controlsHideTimer: Timer?
    private var narrationTimer: Timer?
    private let repository = LyoRepository.shared
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    // MARK: - Session Management
    
    func loadSession(sessionId: String) async {
        state = .loading
        errorMessage = nil
        
        do {
            let session = try await repository.getClassroomSession(id: sessionId)
            self.session = session
            self.settings = session.settings
            
            // Restore progress
            if let moduleId = session.modules.first?.id,
               let progress = session.progress.moduleProgress[moduleId] {
                self.currentSlideIndex = progress.currentSlideIndex
                self.narrationProgress = progress.narrationPosition
            }
            
            state = .ready
            
            print("✅ Session loaded successfully: \(session.modules.count) modules")
            
            // Auto-start narration if enabled
            if settings.autoplayNarration {
                startNarration()
            }
        } catch {
            print("❌ Failed to load session: \(error.localizedDescription)")
            errorMessage = "Failed to load lesson. Please check your internet connection and try again."
            state = .error
        }
    }
    
    func retryLoadSession() async {
        guard let sessionId = session?.id else { return }
        await loadSession(sessionId: sessionId)
    }
    
    // MARK: - Navigation
    
    func nextSlide() {
        guard let session = session else { return }
        let currentModule = session.modules[currentModuleIndex]
        
        if currentSlideIndex < currentModule.slides.count - 1 {
            currentSlideIndex += 1
            saveProgress()
            
            print("📄 Advanced to slide \(currentSlideIndex + 1)/\(currentModule.slides.count)")
            
            // Check if we should show a quick check
            if shouldShowQuickCheck() {
                print("✅ Quick check triggered!")
                showQuickCheck()
            } else if settings.autoplayNarration {
                startNarration()
            }
        } else {
            // Move to next module
            print("📚 Reached end of module, moving to next...")
            nextModule()
        }
    }
    
    func previousSlide() {
        if currentSlideIndex > 0 {
            currentSlideIndex -= 1
            saveProgress()
            if settings.autoplayNarration {
                startNarration()
            }
        }
    }
    
    func nextModule() {
        guard let session = session else { return }
        
        if currentModuleIndex < session.modules.count - 1 {
            currentModuleIndex += 1
            currentSlideIndex = 0
            saveProgress()
            if settings.autoplayNarration {
                startNarration()
            }
        } else {
            completeLesson()
        }
    }
    
    func previousModule() {
        if currentModuleIndex > 0 {
            currentModuleIndex -= 1
            currentSlideIndex = 0
            saveProgress()
            if settings.autoplayNarration {
                startNarration()
            }
        }
    }
    
    func jumpToSlide(moduleIndex: Int, slideIndex: Int) {
        currentModuleIndex = moduleIndex
        currentSlideIndex = slideIndex
        showModuleGrid = false
        saveProgress()
        if settings.autoplayNarration {
            startNarration()
        }
    }
    
    // MARK: - TTS Control
    
    func startNarration() {
        guard let session = session else { 
            print("⚠️ Cannot start narration: No session loaded")
            return 
        }
        let currentModule = session.modules[currentModuleIndex]
        let currentSlide = currentModule.slides[currentSlideIndex]
        
        print("🔊 Starting narration for slide \(currentSlideIndex + 1): \(currentSlide.content.title)")
        
        stopNarration()
        
        let utterance = AVSpeechUtterance(string: currentSlide.narration)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = settings.playbackSpeed * 0.5 // AVSpeechUtterance rate is 0.0-1.0
        
        currentUtterance = utterance
        speechSynthesizer.speak(utterance)
        isNarrating = true
        state = .playing
        
        print("✅ Narration started. Voice bubble should be visible.")
    }
    
    func stopNarration() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isNarrating = false
        narrationProgress = 0.0
        if state == .playing {
            state = .paused
        }
    }
    
    func pauseNarration() {
        speechSynthesizer.pauseSpeaking(at: .word)
        isNarrating = false
        state = .paused
    }
    
    func resumeNarration() {
        speechSynthesizer.continueSpeaking()
        isNarrating = true
        state = .playing
    }
    
    func togglePlayPause() {
        if isNarrating {
            pauseNarration()
        } else if state == .paused {
            resumeNarration()
        } else {
            startNarration()
        }
    }
    
    func changeSpeed(_ newSpeed: Float) {
        let oldSpeed = settings.playbackSpeed
        settings.playbackSpeed = newSpeed
        
        // Restart narration at new speed if currently playing
        if isNarrating {
            let _ = narrationProgress
            startNarration()
            // TODO: Seek to saved position
        }
        
        // Analytics
        print("Speed changed from \(oldSpeed)x to \(newSpeed)x")
    }
    
    func skipForward() {
        // Skip forward 10 seconds in narration
        // TODO: Implement seeking in AVSpeechSynthesizer
    }
    
    func skipBackward() {
        // Skip backward 10 seconds in narration
        // TODO: Implement seeking in AVSpeechSynthesizer
    }
    
    // MARK: - Controls
    
    func showControls() {
        controlsVisible = true
        resetControlsTimer()
    }
    
    func hideControls() {
        controlsVisible = false
    }
    
    func toggleControls() {
        if controlsVisible {
            hideControls()
        } else {
            showControls()
        }
    }
    
    private func resetControlsTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hideControls()
            }
        }
    }
    
    // MARK: - Quick Checks
    
    private func shouldShowQuickCheck() -> Bool {
        // Show check after completing 2nd slide (index 1)
        let frequency = settings.checkFrequency
        
        switch frequency {
        case .fewer: 
            return currentSlideIndex == 1 || currentSlideIndex % 4 == 1
        case .standard: 
            return currentSlideIndex == 1 || currentSlideIndex % 3 == 1
        case .more: 
            return currentSlideIndex > 0 && currentSlideIndex % 2 == 0
        }
    }
    
    private func showQuickCheck() {
        // Load a quick check for current concept
        currentQuickCheck = createMockQuickCheck()
        state = .quickCheck
    }
    
    private func createMockQuickCheck() -> QuickCheck {
        QuickCheck(
            id: "check-1",
            type: .multipleChoice,
            question: "Which part of y = mx + b represents the slope?",
            options: ["y", "m", "x", "b"],
            correctAnswer: "m",
            explanation: "The letter 'm' represents the slope, which is the rate of change of the line.",
            reteachContent: ReteachContent(
                explanation: "Think of slope as how steep a hill is. The steeper the hill, the larger the slope value.",
                analogy: "Imagine climbing stairs. The slope tells you how many steps up you go for each step forward.",
                diagram: nil,
                alternativeApproach: "Slope = Rise over Run. It's the vertical change divided by the horizontal change."
            ),
            timeLimit: 15
        )
    }
    
    func answerCheck(_ answer: String) {
        guard let check = currentQuickCheck else { return }
        
        if answer == check.correctAnswer {
            // Correct answer
            print("Check passed: \(check.id)")
            currentQuickCheck = nil
            state = .ready
            
            // Continue to next slide
            if settings.autoAdvanceAfterNarration {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.nextSlide()
                }
            }
        } else {
            // Wrong answer - show reteach
            if let reteach = check.reteachContent {
                reteachContent = reteach
                showReteach = true
                state = .reteach
            }
        }
    }
    
    func dismissReteach() {
        showReteach = false
        reteachContent = nil
        currentQuickCheck = nil
        state = .ready
        
        // Continue to next slide
        if settings.autoAdvanceAfterNarration {
            nextSlide()
        }
    }
    
    // MARK: - Progress
    
    private func saveProgress() {
        guard let session = session else { return }
        
        // Update progress locally
        slideProgress = Double(currentSlideIndex + 1) / Double(session.modules[currentModuleIndex].slides.count)
        
        let totalSlides = session.modules.reduce(0) { $0 + $1.slides.count }
        let completedSlides = session.modules.prefix(currentModuleIndex).reduce(0) { $0 + $1.slides.count } + currentSlideIndex + 1
        moduleProgress = Double(completedSlides) / Double(totalSlides)
        
        // TODO: Save to backend
    }
    
    private func completeLesson() {
        state = .complete
        // TODO: Save completion to backend
        print("Lesson completed!")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ClassroomViewModel: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isNarrating = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isNarrating = false
            narrationProgress = 1.0
            
            // Auto-advance if enabled
            if settings.autoAdvanceAfterNarration {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.nextSlide()
                }
            }
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isNarrating = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isNarrating = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            currentWordRange = characterRange
            // Update progress based on character position
            let progress = Double(characterRange.location) / Double(utterance.speechString.count)
            narrationProgress = progress
        }
    }
}
