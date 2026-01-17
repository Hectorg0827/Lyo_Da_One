//
//  FlashcardCarouselBubbleView.swift
//  Lyo
//
//  Created for A2UI Dynamic Chat
//

import SwiftUI

struct FlashcardCarouselBubbleView: View {
    let title: String
    let cards: [Flashcard]
    
    // In a real app, you'd want to persist mastery or callback
    @State private var masteredCards: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundStyle(.white)
                Text("STUDY SESSION")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(1)
                Spacer()
                Text("\(title)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Carousel
            TabView {
                ForEach(cards) { card in
                    FlashcardView(card: card, isMastered: masteredCards.contains(card.id)) {
                        toggleMastery(for: card.id)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24) // Space for page indicator
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 300)
            
        }
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func toggleMastery(for cardId: String) {
        if masteredCards.contains(cardId) {
            masteredCards.remove(cardId)
        } else {
            masteredCards.insert(cardId)
        }
    }
}

struct FlashcardView: View {
    let card: Flashcard
    let isMastered: Bool
    let onToggleMastery: () -> Void
    
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            // Back (Answer)
            CardFace(content: card.back, isFlipped: true, isMastered: isMastered)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .opacity(isFlipped ? 1 : 0) // Hide when not flipped to avoid transparency issues
            
            // Front (Question)
            CardFace(content: card.front, isFlipped: false, isMastered: isMastered)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .opacity(isFlipped ? 0 : 1)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                withAnimation {
                    onToggleMastery()
                }
            } label: {
                Image(systemName: isMastered ? "star.fill" : "star")
                    .font(.title2)
                    .foregroundStyle(isMastered ? .yellow : .white.opacity(0.5))
                    .padding()
            }
        }
    }
}

struct CardFace: View {
    let content: String
    let isFlipped: Bool
    let isMastered: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: isFlipped ? 
                            [Color.blue.opacity(0.8), Color.purple.opacity(0.8)] :
                            [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(content)
                .font(isFlipped ? .body : .title3)
                .fontWeight(isFlipped ? .regular : .bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding()
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : 0), // Already handled by parent, no need to flip text?
                    // Actually, if parent rotates Y 180, this text will be backwards unless we handle it
                    // Wait, rotation3DEffect is consistent.
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
        }
        // Add subtle border indicating mastery
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isMastered ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isMastered ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FlashcardCarouselBubbleView(
            title: "Swift Basics",
            cards: [
                Flashcard(front: "What is a 'let' constant?", back: "Immutable value that cannot be changed once set."),
                Flashcard(front: "What is a 'var' variable?", back: "Mutable value that can be changed."),
                Flashcard(front: "What is an Optional?", back: "A type that handles the absence of a value (nil).")
            ]
        )
        .padding()
    }
}
