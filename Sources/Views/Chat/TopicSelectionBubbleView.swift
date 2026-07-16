//
//  TopicSelectionBubbleView.swift
//  Lyo
//
//  Created for Dynamic Chat
//

import SwiftUI

struct TopicSelectionBubbleView: View {
    let title: String
    let topics: [TopicOption]
    let onSelect: (TopicOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(topics) { topic in
                        Button {
                            onSelect(topic)
                        } label: {
                            TopicCard(topic: topic)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }
        }
        .padding(12)
        .background(Color.clear) // Transparent background as cards have their own
    }
}

struct TopicCard: View {
    let topic: TopicOption
    
    var gradients: [Color] {
        if let hexColors = topic.gradientColors {
            return hexColors.map { Color(hex: $0) }
        }
        return [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: topic.icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
            
            Text(topic.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 100)
        .background(
            LinearGradient(
                colors: gradients,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        TopicSelectionBubbleView(
            title: "Choose a Path",
            topics: [
                TopicOption(title: "Algebra", icon: "x.squareroot", gradientColors: ["#FF512F", "#DD2476"]),
                TopicOption(title: "Geometry", icon: "triangle", gradientColors: ["#4CB8C4", "#3CD3AD"]),
                TopicOption(title: "Calculus", icon: "function", gradientColors: ["#1FA2FF", "#12D8FA", "#A6FFCB"])
            ],
            onSelect: { _ in }
        )
    }
}
