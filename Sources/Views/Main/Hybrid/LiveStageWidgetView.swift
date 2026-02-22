
import SwiftUI

struct LiveStageWidgetView: View {
    let widget: [String: Any]
    
    var component: String {
        widget["_component"] as? String ?? "unknown"
    }
    
    var body: some View {
        VStack {
            switch component {
            case "session_start":
                SessionStartWidget(data: widget)
            case "image_card":
                ImageCardWidget(data: widget)
            case "quick_fact":
                QuickFactWidget(data: widget)
            default:
                EmptyView()
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 320)
    }
}

private struct SessionStartWidget: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "FF8C00"))
            
            Text("Ready, \(data["user_name"] as? String ?? "Student")?")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Current focus: \(data["mood"] as? String ?? "Learning")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

private struct ImageCardWidget: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = data["url"] as? String {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.white.opacity(0.1)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(data["title"] as? String ?? "Visual Aid")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(data["caption"] as? String ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
    }
}

private struct QuickFactWidget: View {
    let data: [String: Any]
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "6366F1").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "6366F1"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("DID YOU KNOW?")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(hex: "6366F1"))
                    .kerning(1)
                
                Text(data["text"] as? String ?? "Lyo is learning with you!")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
