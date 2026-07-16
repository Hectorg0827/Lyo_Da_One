import SwiftUI
import CoreLocation

struct CommunityCardView: View {
    let pin: CommunityBeacon
    let isSelected: Bool
    let onJoin: () -> Void
    let onChat: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Type Badge & distance
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: pin.type.icon)
                        .font(.caption2)
                    Text(typeName)
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(pinColor.opacity(0.15))
                .foregroundColor(pinColor)
                .clipShape(Capsule())
                
                Spacer()
                
                if let distance = pin.distance {
                    Text(String(format: "%.1f mi", distance))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            // Content
            HStack(alignment: .top, spacing: 12) {
                // Avatar / Icon
                ZStack {
                    if let imageURL = imageURL {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                    } else {
                        Circle()
                            .fill(pinColor.opacity(0.1))
                            .overlay(
                                Image(systemName: pin.type.icon)
                                    .foregroundColor(pinColor)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(pin.subtitle ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        
                    // Optional Context Pill (e.g. "Lyo Course Linked")
                    if hasLinkedCourse {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("Linked to Course")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    }
                }
            }
            
            // Action Buttons (Only show when selected/expanded)
            if isSelected {
                HStack(spacing: 8) {
                    Button(action: onJoin) {
                        Text(pin.type == .group ? "Join" : "Register") // Updated type check
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onChat) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: isSelected ? pinColor.opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? pinColor : Color.clear, lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    // MARK: - Helpers
    private var pinColor: Color {
        pin.type.color
    }
    
    private var typeName: String {
        pin.type.rawValue
    }
    
    // Optional Context Pill (e.g. "Lyo Course Linked")
    private var hasLinkedCourse: Bool {
        pin.hasLinkedCourse
    }
    
    private var imageURL: String? {
        pin.imageURL
    }
}
