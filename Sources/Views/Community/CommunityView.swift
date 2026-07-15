import SwiftUI
import MapKit

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var showCreateSheet = false
    @State private var showingActivities = false
    @State private var showingLeaderboard = false // NEW
    @State private var selectedTab: CommunityTab = .posts

    enum CommunityTab: CaseIterable {
        case posts, events

        var title: String {
            switch self {
            case .posts: return "Posts"
            case .events: return "Events"
            }
        }

        var icon: String {
            switch self {
            case .posts: return "bubble.left.and.bubble.right.fill"
            case .events: return "mappin.and.ellipse"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Community Tab", selection: $selectedTab) {
                    ForEach(CommunityTab.allCases, id: \.self) { tab in
                        Label(tab.title, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Tab Content
                TabView(selection: $selectedTab) {
                    // Posts Tab - Real Community Feed
                    CommunityFeedView()
                        .tag(CommunityTab.posts)

                    // Events Tab - Community Items (Map/List)
                    CommunityItemsView(viewModel: viewModel)
                        .tag(CommunityTab.events)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Posts tab: CommunityFeedView shows its own create FAB, so a
                // second (previously dead) + here only applies to Events.
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedTab == .events {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCommunityItemSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedPin) { pin in
            CommunityPinDetailSheet(pin: pin)
                .presentationDetents([.medium, .fraction(0.8)])
        }
        .sheet(isPresented: $showingActivities) {
            MyActivitiesView()
        }
        .sheet(isPresented: $showingLeaderboard) {
            GlobalLeaderboardView()
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}

// MARK: - Community Items View (Map/List of Events, Groups, etc.)

struct CommunityItemsView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @State private var showCreateSheet = false
    @State private var showingActivities = false
    @State private var showingLeaderboard = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // MAIN CONTENT LAYER
            Group {
                if viewModel.viewMode == .map {
                    CommunityGoogleStyleMap(viewModel: viewModel)
                } else {
                    CommunityListView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // TOP BAR OVERLAY
            VStack(spacing: 0) {
                CommunityTopBar(viewModel: viewModel, onShowActivities: {
                    showingActivities = true
                }, onShowLeaderboard: {
                    showingLeaderboard = true
                })
                    .background(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    .padding(.trailing, 60) // Add padding to avoid overlap with AppDrawerButton at top right

                Spacer()

                // CURRENT LOCATION BUTTON
                if viewModel.viewMode == .map {
                    HStack {
                        Spacer()
                        Button(action: { viewModel.centerOnUserLocation() }) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.1), radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // Avoid Tab Bar overlap
                    }
                }

                // ADD ITEM FAB
                HStack {
                    Spacer()
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4, y: 3)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            } // end VStack overlay
        } // end ZStack
        .sheet(isPresented: $showCreateSheet) {
            CreateCommunityItemSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingActivities) {
            MyActivitiesView()
        }
        .sheet(isPresented: $showingLeaderboard) {
            GlobalLeaderboardView()
        }
    }
}

// MARK: - Subviews

struct CommunityTopBar: View {
    @ObservedObject var viewModel: CommunityViewModel
    var onShowActivities: () -> Void
    var onShowLeaderboard: () -> Void // NEW
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Search & Toggle
            HStack(spacing: 12) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search events, groups...", text: $viewModel.searchText)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Map/List Toggle
                Picker("Start", selection: $viewModel.viewMode) {
                    Image(systemName: "map.fill").tag(CommunityViewModel.ViewMode.map)
                    Image(systemName: "list.bullet").tag(CommunityViewModel.ViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                
                // Activities Button
                Button(action: onShowActivities) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                // NEW: Leaderboard Button
                Button(action: onShowLeaderboard) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                // NEW: Toggle for real-world discovery (nearby places)
                Button(action: { 
                    withAnimation {
                        viewModel.showNearbyPlaces.toggle()
                    }
                }) {
                    Image(systemName: viewModel.showNearbyPlaces ? "mappin.circle.fill" : "mappin.circle")
                        .font(.title3)
                        .foregroundColor(viewModel.showNearbyPlaces ? .blue : .primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            // Row 2: Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CommunityItemType.crossPlatformCases) { type in
                        FilterPill(
                            title: type.rawValue,
                            icon: type.icon,
                            isSelected: viewModel.selectedFilter == type,
                            color: type.color
                        ) {
                            withAnimation {
                                viewModel.selectedFilter = type
                                if viewModel.viewMode == .map {
                                    // Trigger map refresh or filtering logic
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 12)
        }
        .padding(.top, 10) // Status bar padding handled by safe area usually, but safe to add a bit
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
    }
}

struct FilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }
}

struct CommunityGoogleStyleMap: View {
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        Map(position: $viewModel.mapCameraPosition) {
            ForEach(viewModel.beacons) { beacon in
                Annotation(beacon.title, coordinate: beacon.coordinate) {
                    // Interactive Beacon Pin
                    Button(action: {
                        viewModel.selectedPin = beacon
                    }) {
                        ZStack {
                            Circle()
                                .fill(beacon.type.color)
                                .frame(width: 30, height: 30)
                                .shadow(radius: 2)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            
                            Image(systemName: beacon.type.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(1.0) // Animation hook
                    }
                }
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal]) // Underlay the top bar
        .onMapCameraChange { context in
             viewModel.handleMapRegionChange(context.region)
        }
        // .padding(.bottom) if you want to respect tab bar
    }
}

struct CommunityListView: View {
    @ObservedObject var viewModel: CommunityViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Spacer for top bar
                Spacer().frame(height: 110)
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 50)
                } else if viewModel.filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No items found")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(viewModel.filteredItems) { item in
                        if item.type == .course {
                            if let course = item.courseData {
                                SharedCourseCard(course: course) {
                                  // Action handled by NavigationLink usually, but we can wrap it
                                }
                                .overlay(
                                    NavigationLink(destination: destinationView(for: item)) {
                                        EmptyView()
                                    }
                                    .opacity(0)
                                )
                            }
                        } else {
                            NavigationLink {
                                destinationView(for: item)
                            } label: {
                                CommunityItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 80) // Space for FAB
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Navigation Helper
    
    @ViewBuilder
    private func destinationView(for item: CommunityItem) -> some View {
        switch item.type {
        case .privateLesson:
            if let lessonData = item.lessonData {
                PrivateLessonDetailView(lesson: lessonData)
            } else {
                // Fallback: Create a lesson from item data
                PrivateLessonDetailView(lesson: APIPrivateLesson(
                    id: Int(item.id.hashValue),
                    title: item.title,
                    subject: "General",
                    instructor: APIUserPreview(id: 1, name: "Instructor", avatar: item.userAvatar),
                    cost: 50,
                    durationMinutes: 60,
                    description: item.subtitle,
                    lat: item.coordinate.latitude,
                    lng: item.coordinate.longitude,
                    imageURL: item.imageURL
                ))
            }
            
        case .educationalCenter:
            if let centerData = item.centerData {
                EducationalCenterDetailView(center: centerData)
            } else {
                // Fallback: Create a center from item data
                EducationalCenterDetailView(center: APIEducationalCenter(
                    id: Int(item.id.hashValue),
                    name: item.title,
                    category: "Education",
                    description: item.subtitle ?? "",
                    lat: item.coordinate.latitude,
                    lng: item.coordinate.longitude,
                    address: nil,
                    imageURL: item.imageURL,
                    openingHours: nil
                ))
            }
            
        case .group:
            if let groupData = item.groupData {
                StudyGroupDetailView(group: groupData, viewModel: viewModel)
            } else {
                CommunityItemDetailPlaceholder(item: item)
            }
            
        case .event:
            if let eventData = item.eventData {
                EducationalEventDetailView(event: eventData, viewModel: viewModel)
            } else {
                CommunityItemDetailPlaceholder(item: item)
            }
            
        case .marketplace:
            if let listingData = item.listingData {
                MarketplaceListingDetailView(listing: listingData)
            } else {
                CommunityItemDetailPlaceholder(item: item)
            }
            
        case .course:
            if let courseData = item.courseData {
                // Navigate to classroom directly or a detail view if we have one
                LiveClassroomView(
                    courseId: courseData.id,
                    lessonId: "lesson-1", // Start at beginning
                    courseTitle: courseData.title,
                    lessonTitle: "Lesson 1"
                )
            } else {
                CommunityItemDetailPlaceholder(item: item)
            }
            
        default:
            // Generic detail view for other types (questions, spots, etc.)
            CommunityItemDetailPlaceholder(item: item)
        }
    }
}

// MARK: - Placeholder Detail View

struct CommunityItemDetailPlaceholder: View {
    let item: CommunityItem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero
                ZStack {
                    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                item.type.color.opacity(0.3)
                            }
                        }
                    } else {
                        item.type.color.opacity(0.3)
                    }
                    
                    VStack {
                        Spacer()
                        Text(item.title)
                            .font(.title.bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                            )
                    }
                }
                .frame(height: 200)
                .clipped()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Type badge
                    Label(item.type.rawValue, systemImage: item.type.icon)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(item.type.color.opacity(0.1))
                        .foregroundColor(item.type.color)
                        .clipShape(Capsule())
                    
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Timestamp: \(item.timestamp, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

}

struct CommunityItemCard: View {
    let item: CommunityItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Image (if any)
            if let image = item.imageURL, let url = URL(string: image) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(height: 140)
                .clipped()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    // Type Badge
                    Label(item.type.rawValue, systemImage: item.type.icon)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.type.color.opacity(0.1))
                        .foregroundColor(item.type.color)
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text(item.timestamp, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Footer (Avatar etc)
                HStack {
                    if item.userAvatar != nil {
                        // User Avatar Mock
                        Circle() // AsyncImage here in real app
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    // Action Helper
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// Simple Detail Sheet for Map Pins
struct CommunityPinDetailSheet: View {
    let pin: CommunityBeacon
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Circle()
                .fill(pin.type.color.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: pin.type.icon)
                        .font(.system(size: 32))
                        .foregroundColor(pin.type.color)
                )
                .padding(.top, 40)
            
            Text(pin.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            
            if let sub = pin.subtitle {
                Text(sub)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                Button(action: {
                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: pin.coordinate))
                    mapItem.name = pin.title
                    mapItem.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                }) {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    HapticManager.shared.playLightImpact()
                }) {
                    Label("View Details", systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}
