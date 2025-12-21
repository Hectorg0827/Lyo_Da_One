import SwiftUI
import MapKit
import AVKit

// MARK: - Campus View Mode

// MARK: - Campus View Mode
// Moved to ContentModels.swift to avoid circular/ambiguous reference


// MARK: - Campus View

struct CampusView: View {
    @EnvironmentObject var uiState: AppUIState
    @EnvironmentObject var uiStackStore: UIStackStore
    
    @StateObject private var viewModel = CampusViewModel()
    
    // Navigation state
    @State private var selectedItem: CampusItem?
    @State private var showDetailSheet = false
    @State private var showLioChat = false
    @State private var animateHeader = false
    
    // Map region
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium gradient background
                // Premium gradient background
                LinearGradient(
                    colors: [Color(hexString: "0F172A"), Color(hexString: "1E293B")], // Navy to Slate
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header removed
                    
                    // Error banner (if any)
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                            .padding(.top, 60) // Add padding for App Drawer button
                    } else {
                        // Spacer for App Drawer button if no error
                        Color.clear.frame(height: 60)
                    }
                    
                    // Mode picker
                    premiumModePicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    
                    // Search field
                    premiumSearchField
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    
                    // Type filter chips
                    premiumTypeFilterChips
                        .padding(.bottom, 12)
                    
                    // Content based on mode
                    contentView
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateHeader = true
                }
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let item = selectedItem {
                CampusItemDetailSheet(
                    item: item,
                    isPresented: $showDetailSheet,
                    onJoin: { joinItem(item) },
                    onSave: { viewModel.saveToStack(item: item) },
                    onAskLio: { askLioAbout(item) }
                )
                .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
            }
        }
        .sheet(isPresented: $showLioChat) {
            LioChatSheet(isPresented: $showLioChat)
                .environmentObject(uiState)
        }
        .sheet(isPresented: $uiState.isCreatingEvent) {
            CreateEventView(isPresented: $uiState.isCreatingEvent)
                .environmentObject(uiState)
        }
    }
    
    // MARK: - Header Section
    // Replaced by TopHeaderView
    private var headerSection: some View {
        EmptyView()
    }
    
    // MARK: - Premium Mode Picker
    
    private var premiumModePicker: some View {
        HStack(spacing: 0) {
            ForEach(CampusViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(viewModel.selectedMode == mode ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedMode == mode ? Color.white.opacity(0.15) : Color.clear)
                    )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Premium Search Field
    
    private var premiumSearchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search events, workshops, topics...", text: $viewModel.searchQuery)
                .foregroundColor(.white)
            
            if !viewModel.searchQuery.isEmpty || viewModel.selectedTypeFilter != nil {
                Button(action: viewModel.clearFilters) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Premium Type Filter Chips
    
    private var premiumTypeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CampusItemType.allCases, id: \.self) { type in
                    PremiumFilterChip(
                        title: type.displayName,
                        icon: type.iconName,
                        isSelected: viewModel.selectedTypeFilter == type
                    ) {
                        viewModel.toggleTypeFilter(type)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedMode {
        case .library:
            CampusLibraryView(viewModel: viewModel)
        case .map:
            mapView
        case .list:
            listView
        case .feed:
            feedView
        }
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
        ZStack {
            if #available(iOS 17.0, *) {
                Map(position: .constant(.region(region))) {
                    ForEach(viewModel.filteredItems) { item in
                        Annotation(item.title, coordinate: item.coordinate.clLocation) {
                            CampusMapAnnotation(item: item)
                                .onTapGesture {
                                    selectedItem = item
                                    showDetailSheet = true
                                }
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                // Fallback for older iOS versions
                Map(coordinateRegion: $region, annotationItems: viewModel.filteredItems) { item in
                    MapAnnotation(coordinate: item.coordinate.clLocation) {
                        CampusMapAnnotation(item: item)
                            .onTapGesture {
                                selectedItem = item
                                showDetailSheet = true
                            }
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            
            // Custom Location button overlay (only needed for custom behavior or older iOS)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: centerOnUser) {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.fallbackPrimary)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Live Now Section
                if !viewModel.liveItems.isEmpty {
                    sectionHeader("🔴 Live Now")
                    ForEach(viewModel.liveItems) { item in
                        CampusListRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                                showDetailSheet = true
                            }
                    }
                }
                
                // Today Section
                if !viewModel.todayItems.filter({ !$0.isLive }).isEmpty {
                    sectionHeader("Today")
                    ForEach(viewModel.todayItems.filter { !$0.isLive }) { item in
                        CampusListRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                                showDetailSheet = true
                            }
                    }
                }
                
                // Upcoming Section
                if !viewModel.upcomingItems.isEmpty {
                    sectionHeader("Upcoming")
                    ForEach(viewModel.upcomingItems) { item in
                        CampusListRow(item: item)
                            .onTapGesture {
                                selectedItem = item
                                showDetailSheet = true
                            }
                    }
                }
                
                // Empty state
                if viewModel.filteredItems.isEmpty {
                    emptyState
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Feed View
    
    private var feedView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredItems) { item in
                    CampusFeedCard(item: item)
                        .onTapGesture {
                            selectedItem = item
                            showDetailSheet = true
                        }
                }
                
                if viewModel.filteredItems.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No events found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try a different search or filter")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Text("Retry")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    
    private func centerOnUser() {
        HapticManager.shared.light()
        // In production, use location manager
        region.center = CLLocationCoordinate2D(
            latitude: viewModel.mapCenterLatitude,
            longitude: viewModel.mapCenterLongitude
        )
    }
    
    private func joinItem(_ item: CampusItem) {
        viewModel.joinCollabRoom(item: item, uiState: uiState)
        showDetailSheet = false
    }
    
    private func askLioAbout(_ item: CampusItem) {
        HapticManager.shared.light()
        uiState.lioContextHint = viewModel.buildLioContext(for: item)
        showDetailSheet = false
        // Small delay to allow sheet to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showLioChat = true
        }
    }
}

// MARK: - Campus Filter Chip

struct CampusFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? DesignSystem.Colors.fallbackPrimary : Color(.systemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color(.separator), lineWidth: 1)
            )
        }
    }
}

// MARK: - Map Annotation

struct CampusMapAnnotation: View {
    let item: CampusItem
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(accentColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: item.type.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if item.isLive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 12, y: -12)
                }
            }
            
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(accentColor)
                .offset(y: -3)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private var accentColor: Color {
        switch item.type.accentColor {
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "indigo": return .indigo
        default: return DesignSystem.Colors.fallbackPrimary
        }
    }
}

// MARK: - List Row

struct CampusListRow: View {
    let item: CampusItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item.type.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if item.isLive {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                Text("\(item.formattedTime) • \(item.locationName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Attendees
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(item.attendeeCount)")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.secondary)
                
                if let spots = item.spotsRemaining, spots <= 5 {
                    Text("\(spots) left")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var accentColor: Color {
        switch item.type.accentColor {
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "indigo": return .indigo
        default: return DesignSystem.Colors.fallbackPrimary
        }
    }
}

// MARK: - Feed Card

struct CampusFeedCard: View {
    let item: CampusItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with type and live badge
            HStack {
                Label(item.type.displayName, systemImage: item.type.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentColor)
                
                Spacer()
                
                if item.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Time and location
            HStack(spacing: 16) {
                Label(item.formattedDate, systemImage: "calendar")
                Label(item.formattedTime, systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Label(item.locationName, systemImage: "mappin.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Tags
            if !item.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Footer with host and attendees
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.secondary)
                    Text(item.hostName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(item.attendeeCount)")
                    if let max = item.maxAttendees {
                        Text("/ \(max)")
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var accentColor: Color {
        switch item.type.accentColor {
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "indigo": return .indigo
        default: return DesignSystem.Colors.fallbackPrimary
        }
    }
}

// MARK: - Premium Filter Chip
struct PremiumFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? 
                          LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing) :
                          LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CampusView()
        .environmentObject(AppUIState())
        .environmentObject(UIStackStore.shared)
}

// MARK: - Campus Library View Consolidation
// Imported from CampusLibraryView.swift due to build system issues

struct CampusLibraryView: View {
    @ObservedObject var viewModel: CampusViewModel
    
    @State private var showPlayer = false
    @State private var selectedLessonStartID: String = ""
    @State private var selectedCourse: ContentItem?
    @State private var showCourseDetail = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // 1. Featured Anchor Courses (Carousel)
                featuredSection
                
                // 2. Learning Paths (Timeline/Horizontal)
                pathsSection
                
                // 3. Quick Wins (Micro-Lessons)
                quickWinsSection
                
                // 4. Trending Mini-Courses (Grid)
                trendingSection
            }
            .padding(.bottom, 100)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            MicroLessonPlayerView(
                isPresented: $showPlayer,
                initialLessonID: selectedLessonStartID,
                playlist: viewModel.quickWins
            )
        }
        .sheet(isPresented: $showCourseDetail) {
            if let course = selectedCourse {
                CourseDetailSheet(course: course, isPresented: $showCourseDetail)
            }
        }
    }
    
    // MARK: - Sections
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Featured Courses", icon: "star.fill", color: .yellow)
            
            TabView {
                ForEach(viewModel.featuredContent) { item in
                    FeaturedCourseCard(item: item)
                        .padding(.horizontal, 16)
                        .onTapGesture {
                            selectedCourse = item
                            showCourseDetail = true
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 280)
        }
    }
    
    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Learning Path", icon: "map.fill", color: .blue)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.learningPaths) { item in
                        LearningPathCard(item: item)
                            .onTapGesture {
                                selectedCourse = item
                                showCourseDetail = true
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Quick Wins (Under 5 min)", icon: "bolt.fill", color: .orange)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.quickWins) { item in
                        MicroLessonCard(item: item)
                            .onTapGesture {
                                selectedLessonStartID = item.id
                                showPlayer = true
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Trending Mini-Courses", icon: "chart.line.uptrend.xyaxis", color: .green)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(viewModel.trendingContent) { item in
                    LibraryMiniCourseCard(item: item)
                        .onTapGesture {
                            selectedCourse = item
                            showCourseDetail = true
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Spacer()
            Button("See All") {
                // TODO: Navigate to list
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Components

struct FeaturedCourseCard: View {
    let item: ContentItem
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(hexString: "4F46E5"), Color(hexString: "2563EB")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "book.fill") // Placeholder for cover image
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.1))
                        .offset(x: 100, y: -20)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("FEATURED")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(item.formattedDuration)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text(item.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(item.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                
                HStack {
                    Label(item.author.name, systemImage: "person.circle.fill")
                    Spacer()
                    Text("Start Now")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 8)
            }
            .padding(24)
        }
        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

struct LearningPathCard: View {
    let item: ContentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 120)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.1))
                    .padding()
                
                // Progress Bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * 0.3, height: 4)
                }
                .frame(height: 4)
                .background(Color.white.opacity(0.1))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(item.childContentIds?.count ?? 0) Steps")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: 200)
    }
}

struct MicroLessonCard: View {
    let item: ContentItem
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(item.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(8)
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }
}

struct LibraryMiniCourseCard: View {
    let item: ContentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 100)
                
                Image(systemName: "laptopcomputer")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(0.1))
                    .padding()
                
                if item.isTrending {
                    Text("TRENDING")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Text(item.author.name)
                    Spacer()
                    Label("\(item.stats.views)", systemImage: "eye.fill")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Micro-Lesson Player Consolidation
// Imported from MicroLessonPlayerView.swift

struct MicroLessonPlayerView: View {
    @Binding var isPresented: Bool
    let initialLessonID: String
    let playlist: [ContentItem] // The list of lessons to swipe through
    
    @State private var currentLessonID: String?
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Vertical Paging Feed
            TabView(selection: $currentLessonID) {
                ForEach(playlist) { lesson in
                    MicroLessonCell(lesson: lesson)
                        .tag(Optional(lesson.id))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Standard paging
            .ignoresSafeArea()
            .onAppear {
                if currentLessonID == nil {
                    currentLessonID = initialLessonID
                }
            }
            
            // Close Button
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .padding(.top, 60)
            .padding(.trailing, 20)
        }
        .background(Color.black)
    }
}

struct MicroLessonCell: View {
    let lesson: ContentItem
    
    @State private var isLiked = false
    @State private var showComments = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Video Layer (Mock for now, using Image/Gradient)
            GeometryReader { geo in
                ZStack {
                    Color.black
                    
                    // Fallback visual
                    Image(systemName: "play.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.1))
                    
                    Text("Video Content\n\(lesson.title)")
                        .multilineTextAlignment(.center)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .ignoresSafeArea()
            
            // 2. Overlay Interface
            HStack(alignment: .bottom) {
                // Info Area
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                        Text(lesson.author.name)
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    
                    Text(lesson.title)
                        .font(.body) // TikTok uses normal weight
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(lesson.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                    
                    // Music/Audio tag mock
                    HStack {
                        Image(systemName: "music.note")
                        Text("Original Audio - Lyo Tips")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 60) // Space for tab bar if needed, or just bottom edge
                .padding(.leading, 16)
                
                // Interaction Sidebar
                VStack(spacing: 24) {
                    // Profile/Follow
                    ZStack(alignment: .bottom) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.gray))
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                            .background(Color.white.clipShape(Circle()))
                            .offset(y: 8)
                    }
                    
                    // Like
                    ActionIcon(icon: isLiked ? "heart.fill" : "heart", text: "\(lesson.stats.likes)", color: isLiked ? .red : .white) {
                        withAnimation { isLiked.toggle() }
                        HapticManager.shared.light()
                    }
                    
                    // Comment
                    ActionIcon(icon: "bubble.right.fill", text: "24", color: .white) {
                        showComments.toggle()
                    }
                    
                    // Save
                    ActionIcon(icon: "bookmark.fill", text: "Save", color: .white) {
                        // Save action
                    }
                    
                    // Share
                    ActionIcon(icon: "arrowshape.turn.up.right.fill", text: "Share", color: .white) {
                        // Share action
                    }
                    
                    // Animated Album Art (Spinning)
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
                .padding(.trailing, 10)
                .padding(.bottom, 60)
            }
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
            )
        }
    }
}

struct ActionIcon: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                    .shadow(radius: 4)
                
                Text(text)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Course Detail Sheet

struct CourseDetailSheet: View {
    let course: ContentItem
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hexString: "0A0F1F")
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Hero Image/Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hexString: "4F46E5"), Color(hexString: "2563EB")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 200)
                            
                            Image(systemName: course.type.icon)
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        
                        // Course Info
                        VStack(alignment: .leading, spacing: 16) {
                            // Type Badge
                            Text(course.type.displayName.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.3))
                                .clipShape(Capsule())
                            
                            // Title
                            Text(course.title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            // Meta Info
                            HStack(spacing: 16) {
                                Label(course.formattedDuration, systemImage: "clock")
                                Label(course.level.rawValue.capitalized, systemImage: "chart.bar")
                                Label("\\(course.stats.views)", systemImage: "eye")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            
                            // Description
                            Text(course.description)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(4)
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            // Author
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Instructor")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(course.author.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                            }
                            
                            // Tags
                            if !course.tags.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(course.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.1))
                                            .foregroundColor(.white.opacity(0.8))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            
                            // Learning Path Children
                            if let childIds = course.childContentIds, !childIds.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Learning Path (\(childIds.count) steps)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    ForEach(childIds.indices, id: \.self) { index in
                                        HStack {
                                            Text("\(index + 1)")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.white)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(Color.blue.opacity(0.3)))
                                            
                                            Text("Step \(index + 1)")
                                                .foregroundColor(.white.opacity(0.8))
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 100)
                }
                
                // Start Button (Fixed at Bottom)
                VStack {
                    Spacer()
                    
                    Button(action: {
                        // TODO: Navigate to course content/player
                        print("📚 Starting course: \\(course.title)")
                        HapticManager.shared.medium()
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(course.progress > 0 ? "Continue Learning" : "Start Course")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hexString: "4F46E5"), Color(hexString: "2563EB")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .background(
                        LinearGradient(
                            colors: [Color(hexString: "0A0F1F").opacity(0), Color(hexString: "0A0F1F")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
    }
}

