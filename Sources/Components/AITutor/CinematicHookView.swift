import SwiftUI

/// A visually stunning, cinematic block designed to "hook" the user into a topic.
public struct CinematicHookView: View {
    let data: CinematicHookData
    
    @State private var isVisible = false
    @State private var textOffset: CGFloat = 20
    
    public init(data: CinematicHookData) {
        self.data = data
    }
    
    public var body: some View {
        ZStack {
            // Background (Placeholder for mediaUrl or gradient)
            if let mediaUrl = data.mediaUrl, let url = URL(string: mediaUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        defaultBackground
                    }
                }
            } else {
                defaultBackground
            }
            
            // Scrim
            LinearGradient(
                gradient: Gradient(colors: [
                    .black.opacity(0.8),
                    .black.opacity(0.2),
                    .black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Content
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.title.uppercased())
                        .font(DesignTokens.Typography.labelLarge.bold())
                        .foregroundColor(DesignTokens.Colors.accent)
                        .kerning(4)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: textOffset)
                    
                    Text(data.hook)
                        .font(.system(size: 32, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: textOffset + 10)
                }
                
                if let visualDesc = data.visualDescription {
                    Text(visualDesc)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .opacity(isVisible ? 1 : 0)
                        .offset(y: textOffset + 15)
                }
                
                Spacer()
                
                if let cta = data.callToAction {
                    Button {
                        // Action: Proceed to next block or lessons
                    } label: {
                        HStack {
                            Text(cta)
                            Image(systemName: "arrow.right")
                        }
                        .font(DesignTokens.Typography.labelLarge.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(DesignTokens.Radius.full)
                        .applyShadow(DesignTokens.Shadow.lg)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .frame(minHeight: 450)
        .cornerRadius(DesignTokens.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                isVisible = true
                textOffset = 0
            }
        }
    }
    
    private var defaultBackground: some View {
        ZStack {
            DesignTokens.Colors.surfaceElevated
            
            // Subtle animated elements or noise could go here
            Circle()
                .fill(DesignTokens.Colors.accent.opacity(0.1))
                .blur(radius: 100)
                .offset(x: -100, y: -100)
            
            Circle()
                .fill(DesignTokens.Colors.success.opacity(0.1))
                .blur(radius: 100)
                .offset(x: 100, y: 100)
        }
    }
}

#Preview {
    CinematicHookView(data: CinematicHookData(
        title: "The Silent War",
        hook: "Inside your body, trillions of cells are fighting a battle you'll never see. But without them, life as we know it would vanish in seconds.",
        visualDescription: "Microscopic shot of white blood cells engulfing a virus, illuminated in neon blue and deep violet hues.",
        callToAction: "BEGIN DISCOVERY",
        mediaUrl: nil
    ))
    .padding()
    .background(Color.black)
}
