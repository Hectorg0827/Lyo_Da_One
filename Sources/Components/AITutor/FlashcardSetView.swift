import SwiftUI

public struct FlashcardSetView: View {
    let data: FlashcardSetData
    @State private var currentIndex = 0
    
    public init(data: FlashcardSetData) {
        self.data = data
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                Text(data.title.uppercased())
                    .font(DesignTokens.Typography.labelSmall.bold())
                    .foregroundColor(DesignTokens.Colors.accent)
                
                Spacer()
                
                Text("\(currentIndex + 1) / \(data.cards.count)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DesignTokens.Colors.surfaceHighlight)
            .cornerRadius(DesignTokens.Radius.sm)
            
            // Swipeable cards
            TabView(selection: $currentIndex) {
                ForEach(0..<data.cards.count, id: \.self) { index in
                    FlashcardView(data: data.cards[index])
                        .tag(index)
                        .padding(.bottom, 20) // Space for page indicator
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(minHeight: 280) // Accommodate FlashcardView + indicator
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceElevated.opacity(0.5))
        .cornerRadius(DesignTokens.Radius.lg)
    }
}
