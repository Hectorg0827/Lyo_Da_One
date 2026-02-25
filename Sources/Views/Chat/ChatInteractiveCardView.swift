//
//  ChatInteractiveCardView.swift
//  Lyo
//
//  A premium interactive card for Course proposals, Quizzes, and Flashcards in Chat.
//  Mimics the 3D flipping Card Stack from the Focus Screen.
//

import SwiftUI

enum ChatInteractiveCardType: Equatable {
    case course(title: String, topic: String, level: String, duration: String?, imageURL: URL?)
    case quiz(title: String, questionCount: Int, imageURL: URL?)
    case flashcards(title: String, cardCount: Int, imageURL: URL?)
    
    var title: String {
        switch self {
        case .course(let title, _, _, _, _): return title
        case .quiz(let title, _, _): return title
        case .flashcards(let title, _, _): return title
        }
    }
    
    var subtitle: String {
        switch self {
        case .course(_, let topic, let level, _, _): return "\(level.capitalized) • \(topic)"
        case .quiz(_, let count, _): return "\(count) Questions"
        case .flashcards(_, let count, _): return "\(count) Cards"
        }
    }
    
    var iconName: String {
        switch self {
        case .course: return "book.fill"
        case .quiz: return "checkmark.seal.fill"
        case .flashcards: return "rectangle.stack.fill"
        }
    }
    
    var accentColors: [Color] {
        switch self {
        case .course: return [Color(hex: "8B5CF6"), Color(hex: "6366F1")] // Purple -> Indigo
        case .quiz: return [Color(hex: "F59E0B"), Color(hex: "F97316")]   // Orange
        case .flashcards: return [Color(hex: "10B981"), Color(hex: "06B6D4")] // Teal
        }
    }
    
    var imageURL: URL? {
        switch self {
        case .course(_, _, _, _, let url): return url
        case .quiz(_, _, let url): return url
        case .flashcards(_, _, let url): return url
        }
    }
}

struct ChatInteractiveCardView: View {
    let type: ChatInteractiveCardType
    let onStart: () -> Void
    let onRefine: () -> Void
    let onSave: () -> Void
    
    // Animation States
    @State private var isFlipped = false
    @State private var isPressing = false
    @State private var shakeOffset: CGFloat = 0
    @State private var flipTimer: Timer?
    @State private var isGenerating = false
    
    var body: some View {
        ZStack {
            // Front Side
            frontSide
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back Side
            backSide
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 380)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .scaleEffect(isPressing ? 0.96 : 1.0)
        .offset(x: shakeOffset)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressing = pressing
        }) {
            triggerShakeAndFlip()
        }
    }
    
    // MARK: - Interaction Logic
    private func triggerShakeAndFlip() {
        HapticManager.shared.playMediumImpact()
        
        withAnimation(.linear(duration: 0.05).repeatCount(4, autoreverses: true)) {
            shakeOffset = 6
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) { shakeOffset = 0 }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { isFlipped = true }
            startAutoFlipBackTimer()
        }
    }
    
    private func startAutoFlipBackTimer() {
        flipTimer?.invalidate()
        flipTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { _ in
            withAnimation { isFlipped = false }
        }
    }
    
    // MARK: - Front Side
    private var frontSide: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            ZStack {
                if let url = type.imageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            colorGradientBackground
                        }
                    }
                } else {
                    colorGradientBackground
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                ZStack {
                    Color.black.opacity(0.3) // Darken image slightly for text readability
                    
                    Color.white.opacity(0.03) // Noise
                    LinearGradient(
                        colors: [.white.opacity(0.15), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                    .mask(RoundedRectangle(cornerRadius: 32))
                    
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 8)
            .overlay(glassOrb, alignment: .topTrailing)
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROPOSED")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(type.title)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .frame(maxWidth: 240, alignment: .leading)
                    }
                    Spacer()
                }
                
                Spacer()
                
                Text(type.subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 8)
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Start Button
                    Button {
                        guard !isGenerating else { return }
                        HapticManager.shared.playMediumImpact()
                        isGenerating = true
                        onStart()
                    } label: {
                        HStack(spacing: 6) {
                            if isGenerating {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.8)
                                Text("Starting")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Start")
                            }
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(type.accentColors[0])
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
                    }
                    .disabled(isGenerating)
                    
                    // Refine Button
                    Button {
                        HapticManager.shared.playLightImpact()
                        onRefine()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    
                    // Save Button
                    Button {
                        HapticManager.shared.playLightImpact()
                        onSave()
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Back Side
    private var backSide: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [type.accentColors[0].opacity(0.5), type.accentColors[1].opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Details")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Text(type.title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Divider().background(Color.white.opacity(0.2))
                
                Text("This is an AI-proposed \(type.iconName == "book.fill" ? "course" : (type.iconName == "checkmark.seal.fill" ? "quiz" : "flashcard set")). Press Start to begin learning.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { isFlipped = false }
                }) {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Back to Card")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: type.accentColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
        }
    }
    
    private var glassOrb: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [type.accentColors[0].opacity(0.6), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 30)
                .offset(x: 20, y: 20)
                .overlay(
                    Image(systemName: type.iconName)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white.opacity(0.2))
                )
        }
    }
    
    private var colorGradientBackground: some View {
        LinearGradient(
            colors: type.accentColors.map { $0.opacity(0.9) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
