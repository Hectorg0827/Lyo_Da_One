import SwiftUI

public struct MasteryMapView: View {
    let data: MasteryMapData
    
    public init(data: MasteryMapData) {
        self.data = data
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.blue)
                Text("Mastery Path: \(data.courseTitle)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .padding(.bottom, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    ForEach(Array(data.nodes.enumerated()), id: \.offset) { index, node in
                        HStack(spacing: 24) {
                            MasteryNodeView(node: node)
                            
                            if index < data.nodes.count - 1 {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 30)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct MasteryNodeView: View {
    let node: MasteryNode
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background track
                Circle()
                    .stroke(statusColor.opacity(0.15), lineWidth: 6)
                    .frame(width: 64, height: 64)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(node.masteryLevel))
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: node.masteryLevel)
                
                // Core Icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(statusColor)
                }
            }
            
            VStack(spacing: 4) {
                Text(node.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
                    .lineLimit(2)
                
                Text("\(Int(node.masteryLevel * 100))% Mastered")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    var statusColor: Color {
        switch node.status {
        case "completed": return .green
        case "in_progress": return .blue
        default: return .gray.opacity(0.6)
        }
    }
    
    var iconName: String {
        switch node.status {
        case "completed": return "checkmark.seal.fill"
        case "in_progress": return "sparkles"
        default: return "lock.fill"
        }
    }
}
