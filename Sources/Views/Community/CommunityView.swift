import SwiftUI
import MapKit

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var showCreateSheet = false
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
            .background(DesignTokens.Colors.background)
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
        .onAppear {
            viewModel.loadData()
        }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Community Items View (Map/List of Events, Groups, etc.)

struct CommunityItemsView: View {
    @ObservedObject var viewModel: CommunityViewModel

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
                CommunityTopBar(viewModel: viewModel)
                    .background(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)

                Spacer()
            } // end VStack overlay
        } // end ZStack
    }
}

// MARK: - Subviews

struct CommunityTopBar: View {
    @ObservedObject var viewModel: CommunityViewModel
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
                .onChange(of: viewModel.viewMode) { _, mode in
                    if viewModel.selectedFilter == .group && mode == .map {
                        viewModel.viewMode = .list
                    }
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
                                if type == .group { viewModel.viewMode = .list }
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
                        CommunityItemCard(item: item, viewModel: viewModel)
                    }
                }
            }
            .padding(.bottom, 80) // Space for FAB
        }
        .background(DesignTokens.Colors.background)
    }
}

struct CommunityItemCard: View {
    let item: CommunityItem
    @ObservedObject var viewModel: CommunityViewModel
    @State private var isActive: Bool
    @State private var isBusy = false
    @State private var errorMessage: String?

    init(item: CommunityItem, viewModel: CommunityViewModel) {
        self.item = item
        self.viewModel = viewModel
        _isActive = State(initialValue: item.groupData?.isMember ?? item.eventData?.isAttending ?? false)
    }
    
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
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                }

                Button(action: toggleParticipation) {
                    HStack {
                        if isBusy { ProgressView().tint(.white) }
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(isActive ? DesignTokens.Colors.success.opacity(0.7) : DesignTokens.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                }
                .disabled(isBusy)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background(DesignTokens.Colors.surface)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
        .padding(.horizontal)
        .onChange(of: backendActive) { _, newValue in isActive = newValue }
        .alert("Community error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var backendActive: Bool {
        item.groupData?.isMember ?? item.eventData?.isAttending ?? false
    }

    private var actionTitle: String {
        if item.type == .group { return isActive ? "Leave Group" : "Join Group" }
        return isActive ? "Going ✓" : "RSVP"
    }

    private func toggleParticipation() {
        guard !isBusy else { return }
        let wasActive = isActive
        isActive.toggle()
        isBusy = true
        Task {
            do {
                if item.type == .group {
                    if wasActive { try await viewModel.leaveStudyGroup(id: item.id) }
                    else { try await viewModel.joinStudyGroup(id: item.id) }
                } else {
                    if wasActive { try await viewModel.unregisterFromEvent(id: item.id) }
                    else { try await viewModel.registerForEvent(id: item.id) }
                }
                await MainActor.run { isBusy = false }
            } catch {
                await MainActor.run {
                    isActive = wasActive
                    isBusy = false
                    errorMessage = error.localizedDescription
                }
            }
        }
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
            .padding(.horizontal)
            
            Spacer()
        }
    }
}
