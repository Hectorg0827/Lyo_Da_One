import SwiftUI

struct CommunityDockView: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Binding var isExpanded: Bool
    
    // Local state for tabs
    @State private var selectedTab: DockTab = .nearby
    
    enum DockTab: String, CaseIterable, Identifiable {
        case nearby = "Nearby"
        case forYou = "For You"
        case myGroups = "My Groups"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .nearby: return "location.circle.fill"
            case .forYou: return "sparkles"
            case .myGroups: return "person.3.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            dockContainer
        }
    }
    
    // MARK: - Extracted Subviews
    
    private var dockContainer: some View {
        VStack(spacing: 0) {
            tabBar
            if isExpanded {
                contentPanel
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.75)
        .background(dockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.trailing, 16)
    }
    
    private var dockBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private var tabBar: some View {
        VStack(spacing: 16) {
            ForEach(DockTab.allCases) { tab in
                tabButton(for: tab)
            }
            
            Spacer()
            
            collapseButton
        }
        .padding(.top, 20)
        .frame(width: 70)
        .background(.ultraThinMaterial)
        .overlay(tabBarDivider, alignment: .leading)
    }
    
    private func tabButton(for tab: DockTab) -> some View {
        Button(action: { handleTabTap(tab) }) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                    .frame(width: 44, height: 44)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
                
                if isExpanded && selectedTab == tab {
                    Text(tab.rawValue)
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                        .fixedSize()
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func handleTabTap(_ tab: DockTab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if selectedTab == tab && isExpanded {
                isExpanded = false
            } else {
                selectedTab = tab
                isExpanded = true
            }
        }
        if isExpanded { updateFilterForTab(tab) }
    }
    
    private var collapseButton: some View {
        Button(action: { withAnimation { isExpanded.toggle() } }) {
            Image(systemName: isExpanded ? "chevron.right.circle.fill" : "chevron.left.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
        }
    }
    
    private var tabBarDivider: some View {
        Rectangle()
            .frame(width: 1)
            .foregroundColor(Color.black.opacity(0.1))
            .padding(.vertical, 8)
    }
    
    private var contentPanel: some View {
        VStack(alignment: .leading) {
            Text(selectedTab.rawValue)
                .font(.title3.bold())
                .padding(.horizontal)
                .padding(.top, 20)
            
            Divider().padding(.vertical, 8)
            
            contentScrollView
        }
        .frame(width: 280)
        .background(Color(.systemBackground).opacity(0.95))
        .transition(.move(edge: .trailing))
    }
    
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if currentItems.isEmpty {
                    emptyStateView
                } else {
                    ForEach(currentItems) { pin in
                        cardView(for: pin)
                    }
                }
            }
            .padding(12)
            .padding(.bottom, 100)
        }
    }
    
    private func cardView(for pin: MapPin) -> some View {
        CommunityCardView(
            pin: pin,
            isSelected: viewModel.selectedPin?.id == pin.id,
            onJoin: { handleJoin(pin: pin) },
            onChat: { }
        )
        .onTapGesture {
            HapticManager.shared.selection()
            viewModel.centerMapOnPin(pin)
        }
    }
    
    private func handleJoin(pin: MapPin) {
        Task {
            do {
                if case .studyGroup(let group) = pin.type {
                    try await viewModel.joinStudyGroup(id: group.id)
                } else if case .event(let event) = pin.type {
                    try await viewModel.registerForEvent(id: event.id)
                }
            } catch {
                print("❌ Failed to join: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Logic
    
    private var currentItems: [MapPin] {
        // Filter `viewModel.mapPins` based on `selectedTab`
        // Ideally the VM should handle this, but we can do client-side filtering here for the UI
        switch selectedTab {
        case .nearby:
            return viewModel.mapPins.sorted { ($0.distance ?? 999) < ($1.distance ?? 999) }
        case .forYou:
            // Mock recommendation logic: just shuffle or picking top 5
            return Array(viewModel.mapPins.prefix(5))
        case .myGroups:
            // Filter pins where user is member (Need logic in VM really, but we'll mock it by type)
            return viewModel.mapPins.filter {
                if case .studyGroup = $0.type { return true }
                return false
            }
        }
    }
    
    private func updateFilterForTab(_ tab: DockTab) {
        switch tab {
        case .nearby:
            viewModel.applyFilter(.nearby(radius: 10))
        case .forYou:
            viewModel.applyFilter(.all) // Or a specific For You filter
        case .myGroups:
            viewModel.applyFilter(.studyGroups) // Placeholder
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "binoculars.fill")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Nothing here yet")
                .font(.headline)
            Text("Try exploring other areas tab.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
}
