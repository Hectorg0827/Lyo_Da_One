import SwiftUI

// Advanced Particle structure for the celebration burst
struct Particle: Identifiable, Equatable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var speedX: CGFloat
    var speedY: CGFloat
    var size: CGFloat
    var opacity: Double
    var lifespan: Double
    var color: Color
    var rotation: Angle
    var spinSpeed: Double
}

public struct QuizCardView: View {
    let card: QuizCard
    let palette: LyoLessonPalette
    
    @State private var selectedOptionIndex: Int? = nil
    @State private var showExplanation = false
    
    // Celebration state
    @State private var particles: [Particle] = []
    @State private var celebrationActive = false
    @State private var buttonTapLocation: CGPoint = .zero
    
    public init(card: QuizCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }
    
    public var body: some View {
        ZStack {
            // Background Layer
            AnimatedMeshBackground(palette: palette, phase: 0)
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
            
            // Celebration Canvas Layer (layered over everything except the tapped button)
            if celebrationActive {
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: buttonTapLocation.x + particle.x - particle.size / 2,
                            y: buttonTapLocation.y + particle.y - particle.size / 2, 
                            width: particle.size,
                            height: particle.size
                        )
                        
                        context.opacity = particle.opacity
                        
                        // Draw spinning confetti rectangles
                        var symbolContext = context
                        symbolContext.translateBy(x: rect.midX, y: rect.midY)
                        symbolContext.rotate(by: particle.rotation)
                        symbolContext.translateBy(x: -rect.midX, y: -rect.midY)
                        
                        symbolContext.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color))
                    }
                }
                .ignoresSafeArea()
            }
            
            // Foreground Content
            VStack(spacing: 32) {
                Spacer().frame(height: 100)
                
                Text(card.question)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    ForEach(Array(card.options.enumerated()), id: \.offset) { index, optionText in
                        GeometryReader { proxy in
                            OptionButton(
                                text: optionText,
                                isSelected: selectedOptionIndex == index,
                                isCorrect: showExplanation ? (index == card.correctOptionIndex) : nil,
                                isRevealed: showExplanation
                            ) {
                                // Capture the absolute center of the button for the particle burst origin
                                let frame = proxy.frame(in: .global)
                                buttonTapLocation = CGPoint(x: frame.midX, y: frame.midY)
                                selectOption(index)
                            }
                        }
                        .frame(height: 70) // Fixed height to allow GeometryReader to work predictably within VStack
                    }
                }
                .padding(.horizontal, 24)
                
                if showExplanation, let explanation = card.explanation {
                    Text(explanation)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
            }
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.foregroundDepth))
        }
    }
    
    private func selectOption(_ index: Int) {
        guard !showExplanation else { return } // Prevent re-selection
        
        selectedOptionIndex = index
        withAnimation(.spring()) {
            showExplanation = true
        }
        
        let isCorrect = (index == card.correctOptionIndex)
        LyoAnalyticsManager.shared.trackQuizAttempt(cardId: card.id, isCorrect: isCorrect)
        
        if isCorrect {
            LyoHapticManager.shared.playQuizSuccess()
            triggerCelebration()
        } else {
            // Shake or error bump could go here
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
    
    private func triggerCelebration() {
        celebrationActive = true
        particles.removeAll()
        
        // Colors from palette + some bright accents
        let colors: [Color] = [
            Color(hex: palette.color1Hex) ?? .blue,
            Color(hex: palette.color2Hex) ?? .purple,
            Color(hex: palette.color3Hex) ?? .orange,
            .yellow,
            .cyan,
            .pink
        ]
        
        // Generate 60 explosive particles
        for _ in 0..<60 {
            // Bias particles upwards slightly for an "explosion fountain" look
            let angle = Double.random(in: .pi...2 * .pi) + .pi/2 // Mostly up
            let speed = CGFloat.random(in: 8...25)
            
            let particle = Particle(
                x: 0,
                y: 0,
                speedX: cos(angle) * speed + CGFloat.random(in: -5...5),
                speedY: sin(angle) * speed - CGFloat.random(in: 5...15),
                size: CGFloat.random(in: 5...14),
                opacity: 1.0,
                lifespan: Double.random(in: 0.8...1.5),
                color: colors.randomElement()!,
                rotation: Angle(degrees: Double.random(in: 0...360)),
                spinSpeed: Double.random(in: -10...10)
            )
            particles.append(particle)
        }
        
        // DisplayLink-style physics loop
        let startDate = Date()
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startDate)
            
            var allDead = true
            for i in 0..<particles.count {
                if particles[i].lifespan > 0 {
                    particles[i].x += particles[i].speedX
                    particles[i].y += particles[i].speedY
                    particles[i].speedY += 0.8 // Gravity
                    
                    // Air resistance
                    particles[i].speedX *= 0.95
                    
                    // Spin
                    particles[i].rotation += Angle(degrees: particles[i].spinSpeed)
                    
                    particles[i].lifespan -= 1.0/60.0
                    
                    // Fade out in the last 0.5 seconds of lifespan
                    if particles[i].lifespan < 0.5 {
                        particles[i].opacity = max(0, particles[i].lifespan * 2.0)
                    }
                    
                    allDead = false
                }
            }
            
            if allDead || elapsed > 2.0 {
                timer.invalidate()
                celebrationActive = false
                particles.removeAll()
            }
        }
    }
}

// Custom animated option button
struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool?
    let isRevealed: Bool
    let action: () -> Void
    
    var backgroundColor: Color {
        if isRevealed {
            if isCorrect == true { return .green.opacity(0.8) }
            if isSelected && isCorrect == false { return .red.opacity(0.8) }
        }
        return isSelected ? .white.opacity(0.4) : .white.opacity(0.15)
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Spacer()
                
                if isRevealed {
                    if isCorrect == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    } else if isSelected && isCorrect == false {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(backgroundColor)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected && !isRevealed ? Color.white : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected && !isRevealed ? 0.98 : 1.0)
    }
}
