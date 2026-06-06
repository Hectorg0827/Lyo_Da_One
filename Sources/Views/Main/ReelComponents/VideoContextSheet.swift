import SwiftUI

struct VideoContextSheet: View {
    let item: DiscoverItem
    let onAction: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Drag Indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 10)
            
            // Header
            VStack(spacing: 8) {
                Text("Ask about this video")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.top, 10)
            
            // Lyo Avatar / Branding
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .blue.opacity(0.5), radius: 10)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 10)
            
            // Options Grid
            VStack(spacing: 12) {
                ContextOptionButton(icon: "doc.text", title: "Summarize this video") {
                    onAction("Summarize this video regarding \(item.title). Provide key takeaways.")
                }
                
                ContextOptionButton(icon: "checkmark.circle", title: "Give me a quiz") {
                    onAction("Create a short quiz based on the video: \(item.title).")
                }
                
                ContextOptionButton(icon: "lightbulb", title: "Explain key concepts") {
                    onAction("Explain the key concepts discussed in \(item.title) in simple terms.")
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
    }
}

struct ContextOptionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 30)
                
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}
