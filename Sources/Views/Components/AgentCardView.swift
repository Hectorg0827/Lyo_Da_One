import SwiftUI

struct AgentCardView: View {
    let data: AgentCardData
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                // Agent Icon with Glassmorphism Ring
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: data.icon ?? "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accentColor)
                    
                    if isWorking {
                        Circle()
                            .stroke(accentColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 56, height: 56)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0 : 1)
                            .animation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(data.role)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                StatusBadge(status: data.status)
            }
            
            if let message = data.message {
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary.opacity(0.9))
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.6))
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            if isWorking {
                isAnimating = true
            }
        }
    }
    
    private var isWorking: Bool {
        data.status == "thinking" || data.status == "working"
    }
    
    private var accentColor: Color {
        switch data.name.lowercased() {
        case let name where name.contains("research"): return .blue
        case let name where name.contains("pedagogy"): return .purple
        case let name where name.contains("cinematic"): return .orange
        case let name where name.contains("qa"): return .green
        case let name where name.contains("visual"): return .cyan
        case let name where name.contains("voice"): return .pink
        default: return .blue
        }
    }
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
    }
    
    private var statusText: String {
        switch status.lowercased() {
        case "thinking": return "Thinking..."
        case "working": return "Processing"
        case "completed": return "Ready"
        case "failed": return "Error"
        default: return status.capitalized
        }
    }
    
    private var badgeColor: Color {
        switch status.lowercased() {
        case "thinking", "working": return .orange
        case "completed": return .green
        case "failed": return .red
        default: return .gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AgentCardView(data: AgentCardData(
            name: "Researcher",
            role: "Knowledge Scout",
            status: "working",
            message: "Scanning authoritative sources for 'Quantum Computing' basics...",
            icon: "magnifyingglass"
        ))
        
        AgentCardView(data: AgentCardData(
            name: "Pedagogy Agent",
            role: "Learning Designer",
            status: "thinking",
            message: "Designing cognitive scaffolding for mental models...",
            icon: "brain.head.profile"
        ))
        
        AgentCardView(data: AgentCardData(
            name: "QA Checker",
            role: "Quality Guardian",
            status: "completed",
            message: "All facts verified. No hallucinations detected.",
            icon: "checkmark.shield.fill"
        ))
    }
    .padding()
}
