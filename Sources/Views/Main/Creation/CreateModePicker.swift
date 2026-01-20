//
//  CreateModePicker.swift
//  Lyo
//
//  Horizontal carousel mode picker for Create Hub
//  Inspired by TikTok/Instagram Stories mode switching
//

import SwiftUI

struct CreateModePicker: View {
    @Binding var selectedMode: CreateMode
    let onModeSelected: (CreateMode) -> Void
    
    var body: some View {
        ZStack {
            // Background Fade (TikTok style)
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CreateMode.allCases) { mode in
                        ModeButton(
                            mode: mode,
                            isSelected: selectedMode == mode
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedMode = mode
                                onModeSelected(mode)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(height: 120)
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: CreateMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(mode.iconForMode)
                    .font(.system(size: 14))
                
                Text(mode.rawValue)
                    .font(.system(size: 13, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.1)
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .clipShape(Capsule())
            .shadow(color: isSelected ? Color(hex: "3B82F6").opacity(0.5) : .clear, radius: 10)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
    }
}

extension CreateMode {
    var iconForMode: String {
        switch self {
        case .story: return "📸"
        case .reel, .clip: return "🎬"
        case .post: return "✏️"
        case .course: return "📚"
        case .event: return "🎉"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            CreateModePicker(
                selectedMode: .constant(.reel),
                onModeSelected: { _ in }
            )
            .padding(.bottom, 40)
        }
    }
}
