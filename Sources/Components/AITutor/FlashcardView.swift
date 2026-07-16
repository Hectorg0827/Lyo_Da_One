import SwiftUI

public struct FlashcardView: View {
    let data: FlashcardData
    
    @State private var isFlipped = false
    @State private var degrees: Double = 0
    
    public init(data: FlashcardData) {
        self.data = data
    }
    
    public var body: some View {
        ZStack {
            // Back
            CardContent(
                text: data.back,
                label: "ANSWER",
                labelColor: DesignTokens.Colors.success,
                isFlipped: true
            )
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isFlipped ? 1 : 0)
            
            // Front
            CardContent(
                text: data.front,
                label: "FLASHCARD",
                labelColor: DesignTokens.Colors.warning,
                isFlipped: false
            )
            .opacity(isFlipped ? 0 : 1)
        }
        .rotation3DEffect(.degrees(degrees), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(DesignTokens.Animation.slow) {
                isFlipped.toggle()
                degrees += 180
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.lg)
        .applyShadow(DesignTokens.Shadow.md)
        .contentShape(Rectangle()) // Ensure tap works everywhere
    }
}

private struct CardContent: View {
    let text: String
    let label: String
    let labelColor: Color
    let isFlipped: Bool
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            HStack {
                Text(label)
                    .font(DesignTokens.Typography.labelSmall.bold())
                    .foregroundColor(labelColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(labelColor.opacity(0.1))
                    .cornerRadius(DesignTokens.Radius.sm)
                
                Spacer()
                
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            
            Spacer()
            
            Text(text)
                .font(DesignTokens.Typography.titleMedium)
                .foregroundColor(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignTokens.Spacing.sm)
            
            Spacer()
            
            Text(isFlipped ? "Tap to see question" : "Tap to flip")
                .font(DesignTokens.Typography.caption)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .frame(minHeight: 180)
    }
}
