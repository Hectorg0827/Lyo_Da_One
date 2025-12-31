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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
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
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: CreateMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon Circle
                ZStack {
                    // Outer Glow (when selected)
                    if isSelected {
                        Circle()
                            .fill(mode.color.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .blur(radius: 10)
                    }
                    
                    // Main Circle
                    Circle()
                        .fill(isSelected ? mode.color : Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    // Icon
                    Image(systemName: mode.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                
                // Label
                Text(mode.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                // Indicator Line
                if isSelected {
                    Capsule()
                        .fill(mode.color)
                        .frame(width: 30, height: 3)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Capsule()
                        .fill(.clear)
                        .frame(width: 30, height: 3)
                }
            }
            .frame(width: 80)
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
