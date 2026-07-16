import SwiftUI

public struct ProgressBarView: View {
    let data: ProgressData
    
    @State private var animatedProgress: CGFloat = 0
    
    public init(data: ProgressData) {
        self.data = data
    }
    
    private var progress: CGFloat {
        guard data.total > 0 else { return 0 }
        return CGFloat(data.completed) / CGFloat(data.total)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                if let label = data.label {
                    Text(label)
                        .font(DesignTokens.Typography.labelLarge)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                }
                
                Spacer()
                
                Text("\(data.completed)/\(data.total)")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(DesignTokens.Colors.surfaceHighlight)
                        .frame(height: 8)
                    
                    // Progress bar
                    Capsule()
                        .fill(DesignTokens.Colors.accentGradient)
                        .frame(width: geometry.size.width * animatedProgress, height: 8)
                        .applyShadow(DesignTokens.Shadow.glow)
                }
            }
            .frame(height: 8)
            
            if let sublabel = data.sublabel {
                Text(sublabel)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.md)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
    }
}
