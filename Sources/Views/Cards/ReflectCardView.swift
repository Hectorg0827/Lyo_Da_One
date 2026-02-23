import SwiftUI

public struct ReflectCardView: View {
    let card: ReflectCard
    let palette: LyoLessonPalette
    
    @State private var reflectionText: String = ""
    @State private var isFocusing = false
    @FocusState private var isTextFieldFocused: Bool
    
    public init(card: ReflectCard, palette: LyoLessonPalette) {
        self.card = card
        self.palette = palette
    }
    
    public var body: some View {
        ZStack {
            // Background Layer (Tappable to dismiss keyboard)
            AnimatedMeshBackground(palette: palette, phase: isFocusing ? .pi : 0)
                .opacity(isFocusing ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 1.0), value: isFocusing)
                .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.backgroundDepth))
                .onTapGesture {
                    isTextFieldFocused = false
                    withAnimation {
                        isFocusing = false
                    }
                }
            
            // Foreground Content
            VStack(spacing: 40) {
                Spacer().frame(height: 100)
                
                Text(card.prompt)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // Minimalist Open Text Field
                ZStack(alignment: .topLeading) {
                    if reflectionText.isEmpty {
                        Text("Type your thoughts...")
                            .foregroundColor(Color.white.opacity(0.4))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                    }
                    
                    TextEditor(text: $reflectionText)
                        .focused($isTextFieldFocused)
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(isFocusing ? 0.15 : 0.1))
                                // Soft inner glow/shadow when focused
                                .shadow(color: isFocusing ? .white.opacity(0.1) : .clear, radius: 10, x: 0, y: 0)
                        )
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(isFocusing ? 0.8 : 0.2), lineWidth: isFocusing ? 2 : 1)
                        )
                        .onTapGesture {
                            isTextFieldFocused = true
                        }
                        .onChange(of: isTextFieldFocused) { focused in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFocusing = focused
                            }
                        }
                }
                .frame(maxHeight: 250)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .offset(LyoParallaxManager.shared.offset(for: LyoParallaxManager.shared.foregroundDepth))
        }
        .onDisappear {
            // Log reflection participation when the card disappears
            let words = reflectionText.split(separator: " ").count
            if words > 0 {
                LyoAnalyticsManager.shared.trackReflection(cardId: card.id, wordCount: words)
            }
        }
    }
}
