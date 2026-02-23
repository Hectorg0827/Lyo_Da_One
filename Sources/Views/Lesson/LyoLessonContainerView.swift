import SwiftUI

/// The main orchestrator that streams and displays the Lyo Classroom experience.
public struct LyoLessonContainerView: View {
    let topic: String
    
    @StateObject private var service = LyoClassroomService.shared
    @StateObject private var audioEngine = LyoAudioEngine.shared
    @State private var currentCardIndex: Int = 0
    @State private var cardAppearanceTime: Date? = nil
    @State private var isLessonComplete: Bool = false
    @Namespace private var lessonAnimationNamespace
    
    // Default fallback palette if none exists
    private var activePalette: LyoLessonPalette {
        service.metadata?.palette ?? LyoLessonPalette(color1Hex: "#2B1A4A", color2Hex: "#1A51AC", color3Hex: "#111111")
    }
    
    public init(topic: String) {
        self.topic = topic
    }
    
    public var body: some View {
        ZStack {
            // Error handling state
            if let error = service.error {
                VStack {
                    Text("Classroom Initialization Failed")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Button("Retry") {
                        service.startLessonStream(topic: topic)
                    }
                    .padding()
                }
            } else if service.cards.isEmpty && service.isGenerating {
                // Initial Loading State
                VStack(spacing: 40) {
                    VoiceOrbView(state: .thinking, accent: Color(hex: activePalette.color2Hex) ?? .blue)
                        .matchedGeometryEffect(id: "voice_orb", in: lessonAnimationNamespace)
                    
                    Text("Generating classroom for\n\(topic)...")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            } else if !service.cards.isEmpty {
                // Render the current card
                let currentCard = service.cards[currentCardIndex]
                
                ZStack(alignment: .top) {
                    // Card View Switcher with smooth transitions
                    Group {
                        if let card = currentCard as? ConceptCard {
                            ConceptCardView(card: card, palette: activePalette)
                        } else if let card = currentCard as? DiagramCard {
                            DiagramCardView(card: card, palette: activePalette)
                        } else if let card = currentCard as? AnalogyCard {
                            AnalogyCardView(card: card, palette: activePalette)
                        } else if let card = currentCard as? QuizCard {
                            QuizCardView(card: card, palette: activePalette)
                        } else if let card = currentCard as? ReflectCard {
                            ReflectCardView(card: card, palette: activePalette)
                        } else if let card = currentCard as? SummaryCard {
                            SummaryCardView(card: card, palette: activePalette)
                        } else if let card = currentCard as? TransitionCard {
                            TransitionCardView(card: card, palette: activePalette)
                        }
                    }
                    .id(currentCard.id)
                    .transition(.cinematicPass)
                    
                    // Top Progress Bar
                    if !service.cards.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(0..<service.cards.count, id: \.self) { index in
                                Capsule()
                                    .fill(index <= currentCardIndex ? Color.white : Color.white.opacity(0.3))
                                    .frame(height: 4)
                            }
                            
                            // Streaming indicator
                            if service.isGenerating {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 4, height: 4)
                                    .scaleEffect(cardAppearanceTime != nil ? 1.0 : 0.5)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(), value: currentCardIndex)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 60)
                        .zIndex(50)
                    }
                    
                    // Unified Voice Orb overlay at the top
                    VStack {
                        VoiceOrbView(
                            state: audioEngine.isPlaying ? .speaking : .idle, 
                            accent: Color(hex: activePalette.color2Hex) ?? .blue,
                            amplitude: audioEngine.currentAmplitude
                        )
                        .matchedGeometryEffect(id: "voice_orb", in: lessonAnimationNamespace)
                        .padding(.top, 80)
                        
                        Spacer()
                    }
                    
                    // Navigation Overlays (development only since auto-advance happens via voice usually)
                    HStack {
                        if currentCardIndex > 0 {
                            Button(action: previousCard) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding()
                            }
                        }
                        
                        Spacer()
                        
                        // We can advance if there are more cards, OR if it's still streaming
                        if currentCardIndex < service.cards.count - 1 || service.isGenerating {
                            Button(action: nextCard) {
                                if currentCardIndex < service.cards.count - 1 {
                                    Image(systemName: "chevron.right.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding()
                                } else {
                                    ProgressView()
                                        .tint(.white)
                                        .padding()
                                }
                            }
                        } else if service.streamComplete {
                            Button(action: { 
                                trackCurrentCardDuration()
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    isLessonComplete = true
                                }
                            }) {
                                Text("Finish")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: activePalette.color2Hex) ?? .blue)
                                    .cornerRadius(24)
                                    .padding()
                            }
                        }
                    }
                }
            }
            
            // Celebration Overlay
            if isLessonComplete {
                LessonCompleteView(palette: activePalette) {
                    // Replace this with standard presentationMode dismiss in a full app
                    // For now, we just reset to show the lesson again or you can pop the view.
                    print("Classroom session finished!")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            LyoAnalyticsManager.shared.startSession(topic: topic)
            service.startLessonStream(topic: topic)
            LyoParallaxManager.shared.startTracking()
        }
        .onDisappear {
            // Track the final card before leaving
            trackCurrentCardDuration()
            
            service.stopStream()
            LyoParallaxManager.shared.stopTracking()
            audioEngine.stop()
        }
        .onChange(of: currentCardIndex) { newIndex in
            trackCurrentCardDuration()
            cardAppearanceTime = Date()
            playAudioForCurrentCard()
        }
        .onChange(of: service.cards.count) { count in
            if count == 1 && currentCardIndex == 0 {
                cardAppearanceTime = Date()
                playAudioForCurrentCard()
            }
            // Pre-fetch downstream cards
            for i in sequence(first: currentCardIndex + 1, next: { $0 + 1 }).prefix(2) {
                if i < service.cards.count, let url = service.cards[i].audioUrl {
                    audioEngine.prefetchAudio(from: url)
                }
            }
        }
    }
    
    private func playAudioForCurrentCard() {
        guard currentCardIndex < service.cards.count else { return }
        let card = service.cards[currentCardIndex]
        
        if let audioUrl = card.audioUrl {
            audioEngine.playAudio(from: audioUrl) {
                // Auto advance on completion
                nextCard()
            }
        } else {
            // Audio-less fallback, auto advance after estimated delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if !audioEngine.isPlaying {
                    nextCard()
                }
            }
        }
    }
    
    private func trackCurrentCardDuration() {
        guard currentCardIndex < service.cards.count, let appearanceTime = cardAppearanceTime else { return }
        
        let duration = Date().timeIntervalSince(appearanceTime)
        let cardId = service.cards[currentCardIndex].id
        LyoAnalyticsManager.shared.trackCardView(cardId: cardId, duration: duration)
    }
    
    private func nextCard() {
        if currentCardIndex < service.cards.count - 1 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentCardIndex += 1
            }
        } else if service.streamComplete {
            trackCurrentCardDuration()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isLessonComplete = true
            }
        }
    }
    
    private func previousCard() {
        if currentCardIndex > 0 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentCardIndex -= 1
            }
        }
    }
}

// Custom Cinematic Blur Transition
extension AnyTransition {
    static var cinematicPass: AnyTransition {
        AnyTransition.asymmetric(
            insertion: AnyTransition.modifier(
                active: CinematicModifier(scale: 0.95, blur: 5, opacity: 0),
                identity: CinematicModifier(scale: 1.0, blur: 0, opacity: 1)
            ),
            removal: AnyTransition.modifier(
                active: CinematicModifier(scale: 1.05, blur: 5, opacity: 0),
                identity: CinematicModifier(scale: 1.0, blur: 0, opacity: 1)
            )
        )
    }
}

struct CinematicModifier: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .blur(radius: blur)
            .opacity(opacity)
    }
}
