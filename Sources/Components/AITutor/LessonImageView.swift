import SwiftUI

public struct LessonImageView: View {
    let data: ImageData
    
    public init(data: ImageData) {
        self.data = data
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Image Placeholder/Loader
            // In a real app, this would use the 'query' to fetch from a mapping or search
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(DesignTokens.Colors.surfaceHighlight)
                    .aspectRatio(16/9, contentMode: .fit)
                
                VStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 32))
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                    
                    Text(data.query)
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .stroke(DesignTokens.Colors.surfaceHighlight, lineWidth: 1)
            )
            
            if !data.caption.isEmpty {
                Text(data.caption)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .italic()
                    .padding(.horizontal, 4)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.lg)
    }
}
