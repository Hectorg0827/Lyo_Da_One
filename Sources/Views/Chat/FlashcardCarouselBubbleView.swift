//
//  FlashcardCarouselBubbleView.swift
//  Lyo
//
//  Created for Dynamic Chat
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
                    PremiumFlashcardView(
                        front: card.front,
                        back: card.back,
                        isMastered: masteredCards.contains(card.id),
                        onToggleMastery: {
                            toggleMastery(for: card.id)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 24) // Space for page indicator
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 350)
            
        }
        .background(Color(white: 0.1).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func toggleMastery(for cardId: String) {
        if masteredCards.contains(cardId) {
            masteredCards.remove(cardId)
        } else {
            masteredCards.insert(cardId)
        }
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
