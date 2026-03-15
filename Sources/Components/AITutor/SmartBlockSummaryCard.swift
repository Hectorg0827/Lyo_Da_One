import SwiftUI

public struct SmartBlockSummaryCard: View {
    let data: SummaryData
    
    public init(data: SummaryData) {
        self.data = data
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(DesignTokens.Colors.accent)
                Text(data.title.uppercased())
                    .font(DesignTokens.Typography.labelSmall.bold())
                    .foregroundColor(DesignTokens.Colors.accent)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DesignTokens.Colors.accent.opacity(0.1))
            .cornerRadius(DesignTokens.Radius.sm)
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(data.points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DesignTokens.Colors.success)
                            .padding(.top, 2)
                        
                        Text(point)
                            .font(DesignTokens.Typography.bodyMedium)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.lg)
        .applyShadow(DesignTokens.Shadow.md)
    }
}
