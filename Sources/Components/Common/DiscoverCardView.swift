import SwiftUI

// MARK: - Discover Card View

struct DiscoverCardView: View {
    let item: DiscoverItem
    let onStart: () -> Void
    let onSave: () -> Void
    let onAskLio: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail placeholder
                thumbnailView
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    metadataRow
                }
                
                Spacer()
            }
            
            actionButtons
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }
    
    // MARK: - Subviews
    
    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: thumbnailGradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 80, height: 80)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: item.type.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(tagInitials)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                }
            )
    }
    
    private var metadataRow: some View {
        HStack(spacing: 8) {
            if let tag = item.tag {
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            if let minutes = item.estimatedMinutes {
                Label("\(minutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // Primary action button
            Button(action: onStart) {
                Text(primaryActionLabel)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.fallbackPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // Save button
            Button(action: onSave) {
                Image(systemName: "square.and.arrow.down")
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Ask Lio button
            Button(action: onAskLio) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    // MARK: - Helpers
    
    private var primaryActionLabel: String {
        switch item.type {
        case .courseSuggestion: return "Start Course"
        case .videoSnippet: return "Play Lesson"
        case .pathSuggestion: return "View Path"
        case .eventSuggestion: return "View Event"
        case .userClip: return "Watch Clip"
        }
    }
    
    private var tagInitials: String {
        if let tag = item.tag, !tag.isEmpty {
            return String(tag.prefix(2)).uppercased()
        }
        return "LY"
    }
    
    private var thumbnailGradient: [Color] {
        switch item.type {
        case .courseSuggestion:
            return [Color.purple.opacity(0.8), Color.blue.opacity(0.7)]
        case .videoSnippet:
            return [Color.orange.opacity(0.8), Color.red.opacity(0.7)]
        case .pathSuggestion:
            return [Color.green.opacity(0.8), Color.teal.opacity(0.7)]
        case .eventSuggestion:
            return [Color.pink.opacity(0.8), Color.purple.opacity(0.7)]
        case .userClip:
            return [Color.indigo.opacity(0.8), Color.purple.opacity(0.7)]
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        DiscoverCardView(
            item: DiscoverItem(
                id: "1",
                type: .courseSuggestion,
                title: "Crash Course in Negotiation",
                subtitle: "Master objections in 30 minutes",
                tag: "Sales",
                estimatedMinutes: 30,
                courseId: "course-1",
                lessonId: "lesson-1"
            ),
            onStart: {},
            onSave: {},
            onAskLio: {}
        )
        
        DiscoverCardView(
            item: DiscoverItem(
                id: "2",
                type: .videoSnippet,
                title: "5 Examples of Handling 'Too Expensive'",
                subtitle: "Real-world scenarios",
                tag: "Negotiation",
                estimatedMinutes: 9,
                courseId: "course-1",
                lessonId: "lesson-2"
            ),
            onStart: {},
            onSave: {},
            onAskLio: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
