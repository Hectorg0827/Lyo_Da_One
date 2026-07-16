import SwiftUI

// MARK: - UI Stack Card View

/// A card representing a UI stack item with distinct styling per type
struct UIStackCardView: View {
    let item: UIStackItem
    
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 18)
                .fill(cardGradient)
                .shadow(color: shadowColor, radius: 10, x: 0, y: 6)
            
            // Card content
            VStack(alignment: .leading, spacing: 10) {
                // Top row: Tag + timestamp
                HStack {
                    typeTag
                    Spacer()
                    Text(relativeDate(item.updatedAt))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Title
                Text(item.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // Subtitle
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                // Type-specific content
                typeSpecificContent
            }
            .padding(16)
        }
        .frame(height: cardHeight)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .rotation3DEffect(
            .degrees(Double(dragOffset.width) / 20),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dragOffset)
        .gesture(pressGesture)
    }
    
    // MARK: - Type Tag
    
    private var typeTag: some View {
        HStack(spacing: 4) {
            Image(systemName: typeIcon)
                .font(.caption2)
            Text(item.type.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(typeBadgeColor.opacity(0.2))
        .foregroundColor(typeBadgeColor)
        .cornerRadius(10)
    }
    
    // MARK: - Type-Specific Content
    
    @ViewBuilder
    private var typeSpecificContent: some View {
        switch item.type {
        case .course:
            courseContent
        case .tutor:
            tutorContent
        case .collab:
            collabContent
        case .chat:
            chatContent
        }
    }
    
    private var courseContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Progress bar
            if let progress = item.progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(2)
            }
            
            // Lesson count
            if let total = item.lessonCount {
                let completed = item.completedLessons ?? 0
                Text("\(completed)/\(total) lessons completed")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var tutorContent: some View {
        Group {
            if let lastMessage = item.lastMessage {
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening")
                        .font(.caption2)
                    Text(lastMessage)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var collabContent: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption)
            if let count = item.participantCount {
                Text("\(count) participants")
                    .font(.caption)
            } else {
                Text("Live room")
                    .font(.caption)
            }
        }
        .foregroundColor(.white.opacity(0.7))
    }
    
    private var chatContent: some View {
        Group {
            if let lastMessage = item.lastMessage {
                Text(lastMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Styling Properties
    
    private var cardHeight: CGFloat {
        switch item.type {
        case .course: return 160
        case .tutor: return 130
        case .collab: return 120
        case .chat: return 130
        }
    }
    
    private var cardGradient: LinearGradient {
        let colors: [Color]
        switch item.type {
        case .course:
            colors = [Color(hex: "667EEA"), Color(hex: "764BA2")]
        case .tutor:
            colors = [Color(hex: "A855F7"), Color(hex: "6366F1")]
        case .collab:
            colors = [Color(hex: "3B82F6"), Color(hex: "06B6D4")]
        case .chat:
            colors = [Color(hex: "374151"), Color(hex: "1F2937")]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shadowColor: Color {
        switch item.type {
        case .course: return Color(hex: "667EEA").opacity(0.4)
        case .tutor: return Color(hex: "A855F7").opacity(0.4)
        case .collab: return Color(hex: "3B82F6").opacity(0.4)
        case .chat: return Color.black.opacity(0.3)
        }
    }
    
    private var typeBadgeColor: Color {
        switch item.type {
        case .course: return .yellow
        case .tutor: return .pink
        case .collab: return .cyan
        case .chat: return .white
        }
    }
    
    private var typeIcon: String {
        switch item.type {
        case .course: return "book.fill"
        case .tutor: return "sparkles"
        case .collab: return "person.2.fill"
        case .chat: return "bubble.left.fill"
        }
    }
    
    // MARK: - Gestures
    
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressed { isPressed = true }
                // Subtle tilt effect
                dragOffset = CGSize(
                    width: value.translation.width * 0.3,
                    height: 0
                )
            }
            .onEnded { _ in
                isPressed = false
                dragOffset = .zero
            }
    }
    
    // MARK: - Helpers
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            UIStackCardView(item: UIStackItem(
                type: .course,
                title: "Crash Course in Negotiation",
                subtitle: "Master the art of deals",
                progress: 0.65,
                courseId: "course-1",
                lessonCount: 8,
                completedLessons: 5
            ))
            
            UIStackCardView(item: UIStackItem(
                type: .tutor,
                title: "Tutor: Handling Objections",
                subtitle: "Negotiation Course",
                courseId: "course-1",
                lessonId: "lesson-2",
                lastMessage: "How do I respond to price objections?"
            ))
            
            UIStackCardView(item: UIStackItem(
                type: .collab,
                title: "Study Group: React Basics",
                subtitle: "Live room",
                collabRoomId: "room-1",
                participantCount: 5
            ))
            
            UIStackCardView(item: UIStackItem(
                type: .chat,
                title: "Ask Lio: Career advice",
                subtitle: "Quick chat",
                chatKey: "chat-1",
                lastMessage: "What skills should I focus on?"
            ))
        }
        .padding()
    }
    .background(Color(UIColor.systemBackground))
}
