import SwiftUI

struct ReelHeaderView: View {
    let item: DiscoverItem
    
    var body: some View {
        HStack {
            Spacer()
            
            // Goal Alignment Badge (Optional - kept for context but minimal)
            if let _ = item.linkedGoalId {
                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text("Goal Match")
                        .font(.caption2.bold())
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.4))
                .cornerRadius(12)
            }
        }
        .padding(.top, 60) // Safe area padding handled by parent or here
        .padding(.horizontal, 16)
    }
    
    private func colorForLevel(_ level: LearningLevel) -> Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .yellow
        case .advanced: return .red
        }
    }
}
