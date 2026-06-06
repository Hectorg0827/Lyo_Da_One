//
//  ChatContentViews.swift
//  Lyo
//
//  Reusable content views for chat message rendering.
//

import SwiftUI

// MARK: - Rich Card View

struct RichCardView: View {
    let title: String
    let content: String
    let imageURL: URL?
    let actions: [CardAction]
    let onAction: ((String) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 120)
                            .overlay(ProgressView())
                    }
                }
                .cornerRadius(12, corners: [.topLeft, .topRight])
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
                
                if !actions.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(actions) { action in
                            Button {
                                onAction?(action.id)
                            } label: {
                                Text(action.label)
                                    .font(.caption.bold())
                                    .foregroundColor(action.actionType == "primary" ? .white : .blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        action.actionType == "primary"
                                            ? AnyView(Color.blue)
                                            : AnyView(Color.clear)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Processing Indicator View

struct ProcessingIndicatorView: View {
    let step: String
    let progress: Double?
    
    @State private var frameIndex = 0
    private let frames = ["Mascot_Reading_1", "Mascot_Reading_2", "Mascot_Reading_3", "Mascot_Reading_4"]
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let progress = progress {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 2)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "3B83F6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                }
                
                Image(frames[frameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }
            .onReceive(timer) { _ in
                frameIndex = (frameIndex + 1) % frames.count
            }
            
            Text(step)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
            
            if progress == nil {
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 3, height: 3)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Topic Selection View

struct TopicSelectionView: View {
    let title: String
    let topics: [TopicOption]
    let onSelect: (TopicOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            FlowLayout(spacing: 8) {
                ForEach(topics) { topic in
                    Button {
                        onSelect(topic)
                    } label: {
                        HStack(spacing: 6) {
                            Text(topic.icon)
                            Text(topic.title)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: topic.gradientColors?.map { Color(hex: $0) } ?? [Color.blue, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}
