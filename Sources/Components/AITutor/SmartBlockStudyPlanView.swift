import SwiftUI

struct SmartBlockStudyPlanView: View {
    let data: StudyPlanData
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.success.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundColor(DesignTokens.Colors.success)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(DesignTokens.Typography.titleSmall)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    
                    if let examDate = data.examDate {
                        Text("Exam on \(examDate.formatted(date: .long, time: .omitted))")
                            .font(DesignTokens.Typography.caption)
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .padding(.bottom, 4)
            
            // Sessions List
            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(data.sessions) { session in
                    StudySessionRow(session: session)
                }
            }
            
            // Footer Action
            Button {
                // Potential action: Sync all to calendar (though already done in prep)
                // Or "Mark all as scheduled"
            } label: {
                Text("Study Plan Scheduled ✓")
                    .font(DesignTokens.Typography.labelMedium.bold())
                    .foregroundColor(DesignTokens.Colors.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.success.opacity(0.1))
                    .cornerRadius(DesignTokens.Radius.md)
            }
            .disabled(true)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.surfaceElevated)
        .cornerRadius(DesignTokens.Radius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
                .stroke(DesignTokens.Colors.surfaceHighlight, lineWidth: 1)
        )
    }
}

struct StudySessionRow: View {
    let session: StudySession
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(DesignTokens.Typography.labelMedium.bold())
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                Text(session.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Label("\(session.durationMinutes)m", systemImage: "timer")
                    Label(session.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignTokens.Colors.accentSecondary)
                .padding(.top, 2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(DesignTokens.Colors.textTertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface)
        .cornerRadius(DesignTokens.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .stroke(DesignTokens.Colors.surfaceHighlight.opacity(0.5), lineWidth: 1)
        )
    }
}
