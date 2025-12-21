
import SwiftUI

// MARK: - Creation Option Enum
enum CreationOption {
    case discovery // TikTok style
    case story     // 24h ephemeral
    case post      // Feed post
    case community // Event/Class
}

struct CreationSheet: View {
    @Binding var isPresented: Bool
    let onOptionSelected: (CreationOption) -> Void
    
    var body: some View {
        ZStack {
            // Blur Background
            Color.black.opacity(0.5)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 30) {
                Text("Create")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        // 1. Discovery
                        CreationOptionButton(
                            icon: "play.rectangle.fill",
                            label: "Discovery",
                            color: .purple
                        ) {
                            onOptionSelected(.discovery)
                        }
                        
                        // 2. Story
                        CreationOptionButton(
                            icon: "clock.arrow.circlepath",
                            label: "Story",
                            color: .orange
                        ) {
                            onOptionSelected(.story)
                        }
                    }
                    
                    HStack(spacing: 20) {
                        // 3. Post
                        CreationOptionButton(
                            icon: "square.and.pencil",
                            label: "Post",
                            color: .blue
                        ) {
                            onOptionSelected(.post)
                        }
                        
                        // 4. Community
                        CreationOptionButton(
                            icon: "person.3.fill",
                            label: "Community",
                            color: .green
                        ) {
                            onOptionSelected(.community)
                        }
                    }
                }
                
                // Close Button
                Button {
                    withAnimation {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 20)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(hex: "1E293B"))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 20)
        }
    }
}

struct CreationOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(color)
                }
                
                Text(label)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(width: 90)
        }
    }
}

// VisualEffectBlur is defined in TopHeaderView.swift or shared utility


#Preview {
    CreationSheet(isPresented: .constant(true)) { _ in }
}
