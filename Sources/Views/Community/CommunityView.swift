import SwiftUI
import MapKit

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var showCreateSheet = false
    
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
            }
            
            // FAB (FLOATING ACTION BUTTON)
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 30) // Lift above tab bar slightly if needed
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCommunityItemSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadData()
        }
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
            }
            .padding(.horizontal)
            
            // Row 2: Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CommunityItemType.allCases) { type in
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
                        // Selection logic could go here
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
                } else if viewModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No items found")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 50)
                } else {
                    ForEach(viewModel.items) { item in
                        CommunityItemCard(item: item)
                    }
                }
            }
            .padding(.bottom, 80) // Space for FAB
        }
        .background(Color(.systemGroupedBackground))
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
                    if let avatar = item.userAvatar {
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
