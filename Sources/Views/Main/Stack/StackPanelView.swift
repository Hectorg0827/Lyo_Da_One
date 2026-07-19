import SwiftUI

// MARK: - Stack Panel View

/// Full-screen panel showing all cards in the user's stack
/// This is the "brain drawer" - all courses, tutors, collabs, and chats
struct StackPanelView: View {
    @EnvironmentObject var stackStore: UIStackStore
    @EnvironmentObject var uiState: AppUIState
    
    let onClose: () -> Void
    let onNavigate: (StackNavigationAction) -> Void
    
    @State private var selectedFilter: UIStackItemType? = nil
    @State private var searchText: String = ""
    @State private var appearAnimation = false
    @State private var showAddSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "1E293B"), Color(hex: "0F172A")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                headerSection
                    .padding(.top, 16)
                
                // Search Bar
                glassySearchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Filter chips
                filterBar
                    .padding(.top, 16)
                
                // Section label
                if !filteredItems.isEmpty {
                    HStack {
                        Text(sectionLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.2)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                }
                
                // Cards list or empty state
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    cardsList
                }
                
                Spacer(minLength: 100)
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingAddButton
                        .padding(.trailing, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            // Close button
            Button {
                HapticManager.shared.light()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Title & subtitle
            VStack(spacing: 4) {
                Text("Today's Stack")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(stackSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Lio avatar chip
            lioAvatarChip
        }
        .padding(.horizontal, 20)
    }
    
    private var stackSubtitle: String {
        let count = filteredItems.count
        if count == 0 {
            return "Nothing queued up"
        } else if count == 1 {
            return "1 thing to focus on"
        } else {
            return "\(count) things lined up for you"
        }
    }
    
    private var lioAvatarChip: some View {
        Menu {
            Button {
                // Sort options
            } label: {
                Label("Sort by Date", systemImage: "calendar")
            }
            Button {
                // Sort options
            } label: {
                Label("Sort by Type", systemImage: "square.stack.3d.up")
            }
            Divider()
            Button(role: .destructive) {
                stackStore.removeAll()
            } label: {
                Label("Clear All", systemImage: "trash")
            }
        } label: {
            HStack(spacing: 6) {
                // Lio avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(4)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Glassy Search Bar
    
    private var glassySearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    Text("Search chats, courses, tutors...")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.subheadline)
                }
                TextField("", text: $searchText)
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ModernFilterChip(
                    icon: "square.stack.3d.up.fill",
                    title: "All",
                    count: stackStore.items.count,
                    isSelected: selectedFilter == nil,
                    color: Color(hex: "6366F1")
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = nil
                    }
                }
                
                ModernFilterChip(
                    icon: "book.fill",
                    title: "Course",
                    count: stackStore.items(ofType: .course).count,
                    isSelected: selectedFilter == .course,
                    color: Color(hex: "F59E0B")
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = .course
                    }
                }
                
                ModernFilterChip(
                    icon: "sparkles",
                    title: "Tutor",
                    count: stackStore.items(ofType: .tutor).count,
                    isSelected: selectedFilter == .tutor,
                    color: Color(hex: "EC4899")
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = .tutor
                    }
                }
                
                ModernFilterChip(
                    icon: "person.2.fill",
                    title: "Collab",
                    count: stackStore.items(ofType: .collab).count,
                    isSelected: selectedFilter == .collab,
                    color: Color(hex: "06B6D4")
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = .collab
                    }
                }
                
                ModernFilterChip(
                    icon: "bubble.left.fill",
                    title: "Chat",
                    count: stackStore.items(ofType: .chat).count,
                    isSelected: selectedFilter == .chat,
                    color: Color(hex: "8B5CF6")
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFilter = .chat
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var sectionLabel: String {
        if selectedFilter == nil {
            return "All Items"
        } else {
            return selectedFilter?.displayName ?? "Items"
        }
    }
    
    // MARK: - Cards List
    
    private var cardsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                    ModernStackCard(
                        item: item,
                        onTap: { handleTap(item) },
                        onDelete: { 
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                stackStore.remove(id: item.id)
                            }
                        }
                    )
                    .offset(y: appearAnimation ? 0 : 50)
                    .opacity(appearAnimation ? 1 : 0)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(Double(index) * 0.05),
                        value: appearAnimation
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated empty icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            VStack(spacing: 8) {
                Text("Your stack is empty")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("Courses, tutors, collabs, and chats\nwill appear here as you explore.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            
            // Suggested actions
            suggestedActionsSection
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var suggestedActionsSection: some View {
        VStack(spacing: 12) {
            Text("SUGGESTED FOR YOU")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.2)
                .padding(.top, 20)
            
            // Ghost suggestion cards
            SuggestedGhostCard(
                icon: "sparkles",
                title: "Connect with a tutor",
                subtitle: "Get personalized help"
            )
            
            SuggestedGhostCard(
                icon: "person.2.fill",
                title: "Join a study group",
                subtitle: "Learn together"
            )
        }
    }
    
    // MARK: - Floating Add Button
    
    private var floatingAddButton: some View {
        Button {
            HapticManager.shared.medium()
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Add to Stack")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 15, x: 0, y: 8)
            )
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: appearAnimation)
    }
    
    // MARK: - Filtering
    
    private var filteredItems: [UIStackItem] {
        var items = stackStore.items
        
        // Filter by type
        if let filter = selectedFilter {
            items = items.filter { $0.type == filter }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return items
    }
    
    // MARK: - Navigation
    
    private func handleTap(_ item: UIStackItem) {
        HapticManager.shared.light()
        
        switch item.type {
        case .course:
            if let courseId = item.courseId {
                onNavigate(.openCourse(courseId: courseId))
            }
        case .tutor:
            if let courseId = item.courseId, let lessonId = item.lessonId {
                onNavigate(.openTutor(courseId: courseId, lessonId: lessonId))
            }
        case .collab:
            if let roomId = item.collabRoomId {
                onNavigate(.openCollab(roomId: roomId))
            }
        case .chat:
            onNavigate(.openChat(chatKey: item.chatKey))
        }
    }
}

// MARK: - Modern Filter Chip

private struct ModernFilterChip: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("·")
                        .foregroundColor(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            )
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Stack Card

private struct ModernStackCard: View {
    let item: UIStackItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    @State private var showActions = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                // Card background with radial gradient
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardGradient)
                    .overlay(alignment: .top) {
                        // Thin topic-tinted strip across the top edge for course
                        // items — gives a visual ID without fighting the dark
                        // base. Other item types share the white hairline below.
                        if item.type == .course {
                            TopicArt.gradient(for: item.title)
                                .frame(height: 4)
                                .clipShape(
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: 20,
                                        bottomLeadingRadius: 0,
                                        bottomTrailingRadius: 0,
                                        topTrailingRadius: 20,
                                        style: .continuous
                                    )
                                )
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 15, x: 0, y: 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Top row: Category pill + Time pill
                    HStack {
                        categoryPill
                        Spacer()
                        timePill
                    }
                    
                    // Title
                    Text(item.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    // Details row (time/location/info)
                    if let detailsText = detailsText {
                        HStack(spacing: 6) {
                            Image(systemName: detailsIcon)
                                .font(.caption2)
                            Text(detailsText)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    
                    // Type-specific content + CTA
                    HStack(alignment: .bottom) {
                        typeSpecificContent
                        Spacer()
                        ctaButton
                    }
                }
                .padding(16)
            }
            .frame(minHeight: 140)
        }
        .buttonStyle(CardPressStyle())
        .contextMenu {
            Button {
                // Pin action
            } label: {
                Label("Pin to Top", systemImage: "pin")
            }
            Button {
                // Mark done
            } label: {
                Label("Mark Done", systemImage: "checkmark.circle")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Category Pill
    
    private var categoryPill: some View {
        HStack(spacing: 4) {
            Image(systemName: typeIcon)
                .font(.system(size: 10, weight: .semibold))
            Text(categoryText)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(categoryColor.opacity(0.2))
        .foregroundColor(categoryColor)
        .clipShape(Capsule())
    }
    
    private var categoryText: String {
        switch item.type {
        case .course: return "Course"
        case .tutor: return "Tutor • AI"
        case .collab: return "Collab • Live"
        case .chat: return "Chat"
        }
    }
    
    // MARK: - Time Pill
    
    private var timePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(relativeDate(item.updatedAt))
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .foregroundColor(.white.opacity(0.6))
        .clipShape(Capsule())
    }
    
    // MARK: - Details
    
    private var detailsText: String? {
        switch item.type {
        case .course:
            if let total = item.lessonCount, let completed = item.completedLessons {
                return "\(completed)/\(total) lessons • In progress"
            }
            return nil
        case .tutor:
            return item.subtitle
        case .collab:
            if let count = item.participantCount {
                return "\(count) participants • Live now"
            }
            return "Live room"
        case .chat:
            return nil
        }
    }
    
    private var detailsIcon: String {
        switch item.type {
        case .course: return "play.circle"
        case .tutor: return "book"
        case .collab: return "person.2"
        case .chat: return "bubble.left"
        }
    }
    
    // MARK: - Type-Specific Content
    
    @ViewBuilder
    private var typeSpecificContent: some View {
        switch item.type {
        case .course:
            if let progress = item.progress {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white)
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(width: 100, height: 6)
                    
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                EmptyView()
            }
        case .tutor, .chat:
            if let lastMessage = item.lastMessage {
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                    Text(lastMessage)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: 180, alignment: .leading)
            } else {
                EmptyView()
            }
        case .collab:
            EmptyView()
        }
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        HStack(spacing: 4) {
            Text(ctaText)
                .font(.caption)
                .fontWeight(.semibold)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
        )
    }
    
    private var ctaText: String {
        switch item.type {
        case .course: return "Resume"
        case .tutor: return "Open"
        case .collab: return "Join"
        case .chat: return "Continue"
        }
    }
    
    // MARK: - Styling
    
    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "1E293B"), Color(hex: "0F172A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var shadowColor: Color {
        Color.black.opacity(0.4)
    }
    
    private var categoryColor: Color {
        switch item.type {
        case .course: return Color(hex: "F59E0B")
        case .tutor: return Color(hex: "EC4899")
        case .collab: return Color(hex: "06B6D4")
        case .chat: return Color(hex: "8B5CF6")
        }
    }
    
    private var typeIcon: String {
        switch item.type {
        // Course pills get the topic glyph (function / camera / atom / …) so
        // the pill matches the accent strip and the rest of the app.
        case .course: return TopicArt.iconName(for: item.title)
        case .tutor: return "sparkles"
        case .collab: return "person.2.fill"
        case .chat: return "bubble.left.fill"
        }
    }
    
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Card Press Style

private struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Suggested Ghost Card

private struct SuggestedGhostCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }
            
            Spacer()
            
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
        )
    }
}

// MARK: - Preview

#Preview {
    StackPanelView(
        onClose: {},
        onNavigate: { _ in }
    )
    .environmentObject(UIStackStore.shared)
    .environmentObject(AppUIState())
    .onAppear {
        // Add sample data for preview
        UIStackStore.shared.upsertCourse(
            courseId: "course-1",
            title: "Crash Course in Negotiation",
            subtitle: "Master the art of deals",
            progress: 0.65,
            lessonCount: 8,
            completedLessons: 5
        )
        UIStackStore.shared.upsertTutor(
            courseId: "course-1",
            lessonId: "lesson-2",
            courseTitle: "Negotiation Course",
            lessonTitle: "Handling Objections",
            lastQuestion: "How do I respond to price objections?"
        )
        UIStackStore.shared.upsertCollab(
            roomId: "room-1",
            title: "Study Group: React Basics",
            subtitle: "Live room",
            participantCount: 5
        )
        UIStackStore.shared.upsertChat(
            key: "chat-1",
            title: "Ask Lio: Career advice",
            lastMessage: "What skills should I focus on?"
        )
    }
}
