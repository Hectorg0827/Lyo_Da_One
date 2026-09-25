import SwiftUI
import MapKit

/// What the create sheet opens with: a new item of a kind, or an event to edit.
struct CommunityCreateContext: Identifiable {
    enum Mode {
        case create(CommunityCreationType)
        case edit(APICommunityEventRecord)
    }

    let id = UUID()
    let mode: Mode
}

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var selectedTab: CommunityTab = .aroundMe
    @State private var path: [CommunityNodeRoute] = []
    @State private var createContext: CommunityCreateContext?
    @Environment(\.scenePhase) private var scenePhase

    enum CommunityTab: String, CaseIterable {
        case aroundMe = "Around Me"
        case mine = "My Community"
        case activity = "Activity"
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Community", selection: $selectedTab) {
                    ForEach(CommunityTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .aroundMe:
                    LearningAroundMeView(
                        viewModel: viewModel,
                        openDetail: { openDetail($0) },
                        createEvent: { createContext = CommunityCreateContext(mode: .create(.event)) }
                    )
                case .mine:
                    MyCommunityAccountView(viewModel: viewModel, openRoute: { path.append($0) })
                case .activity:
                    CommunityFeedView()
                }
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { createContext = CommunityCreateContext(mode: .create(.event)) } label: {
                            Label("Learning event", systemImage: "calendar.badge.plus")
                        }
                        Button { createContext = CommunityCreateContext(mode: .create(.group)) } label: {
                            Label("Study group", systemImage: "person.3.fill")
                        }
                        Button { createContext = CommunityCreateContext(mode: .create(.tutor)) } label: {
                            Label("Tutoring", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Create in Community")
                }
            }
            .navigationDestination(for: CommunityNodeRoute.self) { route in
                CommunityNodeDetailView(
                    route: route,
                    viewModel: viewModel,
                    openRoute: { path.append($0) },
                    editEvent: { createContext = CommunityCreateContext(mode: .edit($0)) },
                    onDeleted: { if !path.isEmpty { path.removeLast() } }
                )
            }
        }
        .sheet(item: $createContext) { context in
            CreateCommunityItemSheet(viewModel: viewModel, context: context) { record in
                // A new event opens on its own page, like on the web.
                if case .create(_) = context.mode {
                    path.append(CommunityNodeRoute(kind: "event", id: String(record.id)))
                }
            }
        }
        .sheet(item: $viewModel.selectedPerson) { person in
            CommunityPersonSheet(person: person)
                .presentationDetents([.medium])
        }
        .sheet(item: $viewModel.pendingInvite) { invite in
            CommunityInviteAcceptView(token: invite.token, viewModel: viewModel) { route in
                viewModel.pendingInvite = nil
                path.append(route)
            }
        }
        .onReceive(DeepLinkHandler.shared.$pendingAction) { action in
            // lyoapp://community/invite/<code> from a message or email.
            guard case .openCommunityInvite(let token) = action else { return }
            viewModel.pendingInvite = CommunityInviteToken(token: token)
            DeepLinkHandler.shared.clearPendingAction()
        }
        .overlay(alignment: .bottom) {
            if let message = viewModel.toastMessage {
                CommunityToast(message: message)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.toastMessage)
        .onAppear { viewModel.start() }
        .onChange(of: scenePhase) { _, phase in
            // Back from another app or device: the account may have changed.
            if phase == .active { viewModel.loadData() }
        }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }

    private func openDetail(_ node: APILearningNode) {
        path.append(CommunityNodeRoute(node))
    }
}

// MARK: - Learning Around Me

struct LearningAroundMeView: View {
    @ObservedObject var viewModel: CommunityViewModel
    let openDetail: (APILearningNode) -> Void
    let createEvent: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            // iPad and large windows: results beside the map.
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    LearningAroundControls(viewModel: viewModel)
                    CommunitySheetHeader(viewModel: viewModel)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    sheetContent
                }
                .frame(width: 400)
                .background(DesignTokens.Colors.surface)

                ZStack(alignment: .top) {
                    LearningAroundMap(viewModel: viewModel)
                    mapOverlays
                }
            }
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    LearningAroundMap(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)

                    VStack(spacing: 8) {
                        LearningAroundControls(viewModel: viewModel)
                        mapOverlays
                    }

                    CommunityBottomSheet(
                        detent: $viewModel.sheetDetent,
                        availableHeight: proxy.size.height,
                        topInset: 150,
                        // Room for the app's floating tab bar.
                        bottomInset: 90
                    ) {
                        CommunitySheetHeader(viewModel: viewModel)
                    } content: {
                        sheetContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mapOverlays: some View {
        VStack(spacing: 8) {
            if viewModel.showAreaSearch {
                Button { viewModel.searchThisArea() } label: {
                    Label("Search this area", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(DesignTokens.Colors.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            if showLocationNotice {
                CommunityLocationNotice(viewModel: viewModel)
                    .padding(.horizontal, 12)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showAreaSearch)
    }

    private var showLocationNotice: Bool {
        !viewModel.locationNoticeDismissed &&
            (viewModel.locationState == .denied || viewModel.locationState == .unavailable)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let node = viewModel.selectedNode {
            ScrollView {
                LearningNodePreview(
                    node: viewModel.current(node),
                    viewModel: viewModel,
                    openDetail: { openDetail(viewModel.current(node)) }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 40)
            }
        } else {
            CommunityResultsList(viewModel: viewModel, createEvent: createEvent)
        }
    }
}

// MARK: Controls

private struct LearningAroundControls: View {
    @ObservedObject var viewModel: CommunityViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search a topic, place, or ZIP", text: $viewModel.searchText)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit {
                        searchFocused = false
                        viewModel.submitSearch()
                    }
                    .accessibilityLabel("Search learning opportunities")
                if viewModel.isResolvingSearch {
                    ProgressView().controlSize(.small)
                }
                if !viewModel.searchText.isEmpty || !viewModel.activeQuery.isEmpty {
                    Button { viewModel.clearSearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 32, minHeight: 32)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CommunityFilterChip(
                        title: "All",
                        icon: "sparkles",
                        selected: viewModel.activeFilters.isEmpty,
                        action: { viewModel.clearFilters() }
                    )
                    ForEach(CommunityDiscovery.filters) { filter in
                        CommunityFilterChip(
                            title: filter.label,
                            icon: filter.icon,
                            selected: viewModel.activeFilters.contains(filter.id),
                            action: { viewModel.toggleFilter(filter.id) }
                        )
                    }
                }
                .padding(.vertical, 1)
            }

            if !viewModel.people.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.people) { person in
                            Button { viewModel.selectedPerson = person } label: {
                                HStack(spacing: 7) {
                                    AvatarBubble(
                                        name: person.name ?? person.username ?? "Member",
                                        url: person.avatarURL,
                                        size: 28
                                    )
                                    Text(person.name ?? person.username ?? "Member")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Person: \(person.name ?? person.username ?? "Member")")
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

private struct CommunityFilterChip: View {
    let title: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? DesignTokens.Colors.accent : Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

private struct CommunityLocationNotice: View {
    @ObservedObject var viewModel: CommunityViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "location.slash")
                .foregroundStyle(DesignTokens.Colors.accentSecondaryLight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.locationState == .denied
                     ? "Location is off — showing \(viewModel.locationLabel). Search a city or ZIP, or allow location."
                     : "Couldn't find your location — showing \(viewModel.locationLabel). Search a city or ZIP instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if viewModel.locationState == .denied, let settings = URL(string: UIApplication.openSettingsURLString) {
                    Button("Open Settings") { openURL(settings) }
                        .font(.caption.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
            Button { viewModel.locationNoticeDismissed = true } label: {
                Image(systemName: "xmark").font(.caption.weight(.bold))
            }
            .frame(minWidth: 32, minHeight: 32)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(DesignTokens.Colors.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
    }
}

// MARK: Map

private struct LearningAroundMap: View {
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        GeometryReader { proxy in
            let clusters = makeClusters(width: proxy.size.width)
            Map(position: $viewModel.mapCameraPosition) {
                UserAnnotation()
                ForEach(clusters) { cluster in
                    Annotation(
                        cluster.members.count == 1 ? (cluster.members.first?.title ?? "") : "\(cluster.members.count) places",
                        coordinate: CLLocationCoordinate2D(latitude: cluster.latitude, longitude: cluster.longitude),
                        anchor: .center
                    ) {
                        if cluster.members.count == 1, let node = cluster.members.first {
                            Button { viewModel.select(node) } label: {
                                LearningMapPin(node: node, selected: viewModel.selectedNode?.key == node.key)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(node.categoryLabel): \(node.title)")
                            .accessibilityHint("Shows a preview")
                        } else {
                            Button { viewModel.openCluster(cluster) } label: {
                                ClusterBubble(count: cluster.members.count)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(cluster.members.count) learning opportunities here")
                            .accessibilityHint("Zooms in or lists them")
                        }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.mapCameraChanged(context.region)
            }
            .overlay(alignment: .topTrailing) {
                Button { viewModel.centerOnUserLocation() } label: {
                    Image(systemName: viewModel.locationState == .granted ? "location.fill" : "location")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .padding(.top, 200)
                .accessibilityLabel("Show learning near me")
            }
        }
    }

    private func makeClusters(width: CGFloat) -> [CommunityDiscovery.Cluster] {
        let region = viewModel.region
        let world = CommunityDiscovery.worldSize(longitudeDelta: region.span.longitudeDelta, viewWidth: Double(width))
        return CommunityDiscovery.cluster(viewModel.mapNodes, cellPoints: 52) { node in
            CommunityDiscovery.project(latitude: node.latitude ?? 0, longitude: node.longitude ?? 0, worldSize: world)
        }
    }
}

private struct LearningMapPin: View {
    let node: APILearningNode
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(node.categoryColor)
                .frame(width: selected ? 42 : 34, height: selected ? 42 : 34)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: selected ? 3 : 2.5))
                .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
            Image(systemName: node.categoryIcon)
                .font(.system(size: selected ? 18 : 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .opacity(node.hasEnded ? 0.6 : 1)
        .frame(width: 48, height: 48)
        .contentShape(Rectangle())
    }
}

private struct ClusterBubble: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(DesignTokens.Colors.accent, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2.5))
            .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
    }
}

// MARK: Bottom sheet

/// Map-first bottom sheet with collapsed, medium, and expanded heights. It is
/// an overlay rather than a presented sheet so it never covers the tab bar.
private struct CommunityBottomSheet<Header: View, Content: View>: View {
    @Binding var detent: CommunityViewModel.SheetDetent
    let availableHeight: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content
    @GestureState private var drag: CGFloat = 0

    private let collapsedHeight: CGFloat = 92

    private func height(for detent: CommunityViewModel.SheetDetent) -> CGFloat {
        let usable = availableHeight - bottomInset
        let tallest = max(collapsedHeight + 60, usable - topInset)
        switch detent {
        case .collapsed: return collapsedHeight
        case .medium: return min(max(280, usable * 0.5), tallest)
        case .expanded: return tallest
        }
    }

    var body: some View {
        let base = height(for: detent)
        let current = min(max(collapsedHeight, base - drag), height(for: .expanded))
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                header()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { cycle() }
            .gesture(
                DragGesture(minimumDistance: 6)
                    .updating($drag) { value, state, _ in state = value.translation.height }
                    .onEnded { value in
                        let projected = base - value.predictedEndTranslation.height
                        let options: [CommunityViewModel.SheetDetent] = [.collapsed, .medium, .expanded]
                        detent = options.min {
                            abs(height(for: $0) - projected) < abs(height(for: $1) - projected)
                        } ?? .medium
                    }
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(detent == .expanded ? "Double tap to show more map" : "Double tap to show more results")

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .opacity(detent == .collapsed && drag >= 0 ? 0 : 1)
                .accessibilityHidden(detent == .collapsed)
        }
        .frame(height: current, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.surface.opacity(0.98))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
        .shadow(color: .black.opacity(0.35), radius: 16, y: -4)
        .padding(.bottom, bottomInset)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: detent)
    }

    private func cycle() {
        switch detent {
        case .collapsed: detent = .medium
        case .medium: detent = .expanded
        case .expanded: detent = .medium
        }
    }
}

private struct CommunitySheetHeader: View {
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if viewModel.selectedNode != nil {
                Button { viewModel.closePreview() } label: {
                    Label("All results", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(minHeight: 36)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.resultsTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
        }
    }

    private var subtitle: String? {
        var parts = CommunityDiscovery.activeFilterLabels(viewModel.activeFilters)
        if !viewModel.activeQuery.isEmpty { parts.insert("“\(viewModel.activeQuery)”", at: 0) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: Results

private struct CommunityResultsList: View {
    @ObservedObject var viewModel: CommunityViewModel
    let createEvent: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if viewModel.clusterKeys != nil {
                    Button { viewModel.clusterKeys = nil } label: {
                        Label("Show everything in this area", systemImage: "xmark")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if let error = viewModel.loadError, !viewModel.nearbyNodes.isEmpty {
                    CommunityNotice(
                        icon: "clock.arrow.circlepath",
                        text: "\(error.title) Showing earlier results.",
                        actionTitle: error.retry ? "Retry" : nil,
                        action: { viewModel.retry() }
                    )
                }
                if !viewModel.degradedSources.isEmpty && viewModel.loadError == nil {
                    CommunityNotice(
                        icon: "exclamationmark.triangle",
                        text: "Some nearby places couldn't load right now. Events and groups are up to date.",
                        actionTitle: "Retry",
                        action: { viewModel.retry() }
                    )
                }

                if viewModel.isLoading && viewModel.nearbyNodes.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in LearningNodeSkeleton() }
                } else if let error = viewModel.loadError, viewModel.nearbyNodes.isEmpty {
                    CommunityStateView(
                        icon: error == CommunityDiscovery.offlineError ? "wifi.slash" : "map",
                        title: error.title,
                        message: error.body,
                        actions: error.retry ? [("Try again", { viewModel.retry() })] : []
                    )
                } else if viewModel.listNodes.isEmpty && viewModel.hasLoadedOnce {
                    CommunityStateView(
                        icon: "sparkle.magnifyingglass",
                        title: "No learning opportunities here yet",
                        message: emptyMessage,
                        actions: emptyActions
                    )
                } else {
                    ForEach(viewModel.listNodes, id: \.key) { node in
                        LearningNodeRow(node: node) { viewModel.select(node) }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 60)
        }
        .refreshable { viewModel.loadData() }
    }

    private var emptyMessage: String {
        if !viewModel.activeFilters.isEmpty || !viewModel.activeQuery.isEmpty {
            return "Try fewer filters, a different topic, or a wider area."
        }
        return "Try a wider area, or be the first to host a learning event here."
    }

    private var emptyActions: [(String, () -> Void)] {
        var actions: [(String, () -> Void)] = []
        if !viewModel.activeFilters.isEmpty { actions.append(("Clear filters", { viewModel.clearFilters() })) }
        if !viewModel.activeQuery.isEmpty { actions.append(("Clear search", { viewModel.clearSearch() })) }
        actions.append(("Search a wider area", { viewModel.widenSearch() }))
        actions.append(("Create an event", createEvent))
        return actions
    }
}

private struct CommunityNotice: View {
    let icon: String
    let text: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(DesignTokens.Colors.warning).accessibilityHidden(true)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 32)
            }
        }
        .padding(10)
        .background(DesignTokens.Colors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CommunityStateView: View {
    let icon: String
    let title: String
    let message: String
    var actions: [(String, () -> Void)] = []

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                if index == 0 {
                    Button(action.0, action: action.1)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                } else {
                    Button(action.0, action: action.1)
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
}

private struct LearningNodeSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.07)).frame(width: 180, height: 11)
            }
        }
        .padding(12)
        .background(DesignTokens.Colors.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 15))
        .accessibilityHidden(true)
    }
}

struct LearningNodeRow: View {
    let node: APILearningNode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: node.categoryIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(node.categoryColor)
                    .frame(width: 44, height: 44)
                    .background(node.categoryColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(node.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        if node.isSaved {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(DesignTokens.Colors.accent)
                                .accessibilityLabel("Saved")
                        }
                    }
                    HStack(spacing: 6) {
                        Text(node.categoryLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(node.categoryColor)
                        if let badge = node.statusBadge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(node.statusBadgeColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(node.statusBadgeColor)
                        }
                    }
                    if !node.metaLine.isEmpty {
                        Text(node.metaLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    if let place = node.placeLine {
                        Text(place)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(DesignTokens.Colors.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 15))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows a preview")
    }
}

// MARK: Preview

/// What a marker tap shows: enough to decide, with the main actions, without
/// leaving the map.
struct LearningNodePreview: View {
    let node: APILearningNode
    @ObservedObject var viewModel: CommunityViewModel
    let openDetail: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: node.categoryIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(node.categoryColor)
                    .frame(width: 46, height: 46)
                    .background(node.categoryColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(node.categoryLabel.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(node.categoryColor)
                        if let badge = node.statusBadge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(node.statusBadgeColor)
                        }
                    }
                    Text(node.title)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 0)
                Button { viewModel.closePreview() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Close preview")
            }

            VStack(alignment: .leading, spacing: 6) {
                if let when = node.whenText {
                    CommunityInfoLine(icon: "clock", text: when)
                }
                if let place = node.placeLine {
                    CommunityInfoLine(
                        icon: node.attendanceMode == "online" ? "video" : "mappin.and.ellipse",
                        text: [place, node.distanceText].compactMap { $0 }.joined(separator: " · ")
                    )
                } else if let distance = node.distanceText {
                    CommunityInfoLine(icon: "location", text: distance)
                }
                if let organizer = node.organizerLine {
                    CommunityInfoLine(icon: "person", text: organizer)
                }
                if let price = node.priceText {
                    CommunityInfoLine(icon: "tag", text: price)
                }
                if let people = node.peopleLine {
                    CommunityInfoLine(icon: "person.2", text: people)
                }
                if let hours = node.openingHours, !hours.isEmpty {
                    CommunityInfoLine(icon: "clock.badge.checkmark", text: hours)
                }
            }

            if let text = node.description ?? node.relevance, !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            CommunityPrimaryActions(node: node, viewModel: viewModel)

            HStack(spacing: 8) {
                Button(action: openDetail) {
                    Label("View details", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let directions = CommunityDiscovery.directionsURL(node) {
                    Button {
                        viewModel.track("community_directions_opened", ["kind": node.kind])
                        openURL(directions)
                    } label: {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("Directions")
                }
            }
        }
        .padding(.top, 4)
    }
}

/// RSVP / join and save: the same controls in the preview and on the detail page.
struct CommunityPrimaryActions: View {
    let node: APILearningNode
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        let busy = viewModel.isBusy(node)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if node.kind == "event" {
                    if node.lifecycle == "cancelled" {
                        Label("Cancelled", systemImage: "xmark.octagon")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.danger)
                    } else if node.lifecycle == "past" {
                        Label("This event has ended", systemImage: "clock.badge.xmark")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            Task { await viewModel.setRSVP(node, status: node.isGoing ? nil : "going") }
                        } label: {
                            Label(
                                node.isGoing || node.isFull != true ? "Going" : "Full",
                                systemImage: node.isGoing ? "checkmark.circle.fill" : "checkmark.circle"
                            )
                        }
                        .buttonStyle(RSVPButtonStyle(selected: node.isGoing))
                        .disabled(busy || (node.isFull == true && !node.isGoing))
                        .accessibilityHint(node.isGoing ? "Removes your RSVP" : "RSVP as going")

                        Button {
                            Task { await viewModel.setRSVP(node, status: node.isInterested ? nil : "interested") }
                        } label: {
                            Label("Interested", systemImage: node.isInterested ? "star.fill" : "star")
                        }
                        .buttonStyle(RSVPButtonStyle(selected: node.isInterested))
                        .disabled(busy)
                    }
                } else if node.kind == "study_group" {
                    Button {
                        Task { await viewModel.toggleMembership(node) }
                    } label: {
                        Label(node.isJoined ? "Joined" : "Join group", systemImage: node.isJoined ? "checkmark.circle.fill" : "person.badge.plus")
                    }
                    .buttonStyle(RSVPButtonStyle(selected: node.isJoined))
                    .disabled(busy)
                }

                Button {
                    Task { await viewModel.toggleSave(node) }
                } label: {
                    Label(node.isSaved ? "Saved" : "Save", systemImage: node.isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(RSVPButtonStyle(selected: node.isSaved))
                .disabled(busy)
            }
        }
    }
}

private struct RSVPButtonStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                selected ? DesignTokens.Colors.accent : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.5)
    }
}

struct CommunityInfoLine: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
        }
    }
}

struct CommunityToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.85), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12)))
            .padding(.horizontal, 24)
            .accessibilityAddTraits(.updatesFrequently)
            .onAppear { UIAccessibility.post(notification: .announcement, argument: message) }
    }
}

// MARK: - Account-owned Community

private struct MyCommunityAccountView: View {
    @ObservedObject var viewModel: CommunityViewModel
    let openRoute: (CommunityNodeRoute) -> Void

    var body: some View {
        ScrollView {
            if let account = viewModel.myCommunity {
                LazyVStack(alignment: .leading, spacing: 12) {
                    accountHeader

                    if let invited = account.invited, !invited.isEmpty {
                        sectionTitle("Invited", icon: "envelope.open.fill")
                        ForEach(invited, id: \.key) { node in
                            LearningNodeRow(node: node) { openRoute(CommunityNodeRoute(node)) }
                        }
                    }
                    CommunityInviteLinkField(viewModel: viewModel)

                    section("Going", icon: "checkmark.circle.fill",
                            nodes: account.going ?? [],
                            empty: "Events you RSVP to appear here on every device.")
                    section("Interested", icon: "star.fill",
                            nodes: account.interested ?? [],
                            empty: "Tap Interested on an event to keep an eye on it.")
                    section("Hosting", icon: "megaphone.fill",
                            nodes: account.hosting ?? [],
                            empty: "Events you create appear here, including private drafts.")
                    section("Saved", icon: "bookmark.fill",
                            nodes: account.savedNodes,
                            empty: "Save a library, museum, class, or event and it will appear here on every device.")

                    sectionTitle("Study groups", icon: "person.3.fill")
                    ForEach(account.joinedGroups) { group in
                        Button { openRoute(CommunityNodeRoute(kind: "study_group", id: String(group.id))) } label: {
                            accountCard(
                                group.name,
                                subtitle: [group.memberCount.map { "\($0) members" }, group.isOnline ? "Online" : group.location]
                                    .compactMap { $0 }.joined(separator: " · ")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if account.joinedGroups.isEmpty { empty("You haven't joined a study group yet.") }

                    sectionTitle("People you follow", icon: "person.2.fill")
                    ForEach(account.following, id: \.id) { person in
                        Button { viewModel.selectedPerson = APISearchUser(id: person.id, username: nil, name: person.name, avatarURL: person.avatar) } label: {
                            HStack(spacing: 10) {
                                AvatarBubble(name: person.name, url: person.avatar, size: 38)
                                Text(person.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    if account.following.isEmpty { empty("People you follow will appear here.") }
                }
                .padding(14)
                .padding(.bottom, 90)
            } else if let error = viewModel.accountError {
                CommunityStateView(
                    icon: error == CommunityDiscovery.offlineError ? "wifi.slash" : "person.crop.circle.badge.exclamationmark",
                    title: error.title,
                    message: error.body,
                    actions: [("Try again", { viewModel.refreshAccount() })]
                )
                .padding(.top, 60)
            } else {
                ProgressView("Loading your Community…")
                    .padding(.top, 80)
            }
        }
        .refreshable { await viewModel.reloadAccount() }
        .background(DesignTokens.Colors.background)
    }

    @ViewBuilder
    private func section(_ title: String, icon: String, nodes: [APILearningNode], empty text: String) -> some View {
        sectionTitle(title, icon: icon)
        ForEach(nodes, id: \.key) { node in
            LearningNodeRow(node: node) { openRoute(CommunityNodeRoute(node)) }
        }
        if nodes.isEmpty {
            // Older backends list RSVPs only as attending events.
            if title == "Going", let events = viewModel.myCommunity?.attendingEvents, !events.isEmpty {
                ForEach(events) { event in
                    Button { openRoute(CommunityNodeRoute(kind: "event", id: String(event.id))) } label: {
                        accountCard(
                            event.title,
                            subtitle: [APILearningNode.formattedDate(event.startTime), event.isOnline ? "Online" : event.location]
                                .compactMap { $0 }.joined(separator: " · ")
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                empty(text)
            }
        }
    }

    private var accountHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("One Community, every device")
                .font(.headline)
            Text("Your saves, RSVPs, groups, and hosted events belong to your Lyo account — not this iPhone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DesignTokens.Colors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func accountCard(_ title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).padding(.vertical, 6)
    }
}

// MARK: - Shared helpers

extension APILearningNode {
    var categoryLabel: String {
        CommunityDiscovery.categoryLabel(category: category, placeType: placeType)
    }

    var categoryIcon: String {
        switch category {
        case "event": return "calendar"
        case "workshop": return "hammer.fill"
        case "class": return "graduationcap.fill"
        case "study_group": return "person.3.fill"
        case "tutor": return "person.crop.circle.badge.checkmark"
        case "library": return "books.vertical.fill"
        case "museum": return "building.columns.fill"
        case "educational_center": return "building.2.fill"
        default: return "mappin"
        }
    }

    var categoryColor: Color {
        switch category {
        case "event": return .orange
        case "workshop": return .yellow
        case "class": return .purple
        case "study_group": return .blue
        case "tutor": return .pink
        case "library": return .green
        case "museum": return .cyan
        case "educational_center": return .indigo
        default: return .gray
        }
    }

    var isGoing: Bool { rsvpStatus == "going" || (rsvpStatus == nil && isAttending) }
    var isInterested: Bool { rsvpStatus == "interested" }
    var hasEnded: Bool { lifecycle == "past" || lifecycle == "cancelled" }

    var whenText: String? { CommunityDiscovery.formatWhen(startsAt, endsAt) }
    var distanceText: String? { CommunityDiscovery.formatDistance(distanceKm) }
    var priceText: String? { CommunityDiscovery.formatPrice(isFree: isFree, amount: priceAmount, currency: currency) }

    var statusBadge: String? {
        switch lifecycle ?? "" {
        case "today", "live", "past", "cancelled": return lifecycle.flatMap { CommunityDiscovery.lifecycleLabels[$0] }
        default: return visibility == "private" ? "Private" : (visibility == "unlisted" ? "Unlisted" : nil)
        }
    }

    var statusBadgeColor: Color {
        switch lifecycle ?? "" {
        case "live", "today": return DesignTokens.Colors.success
        case "cancelled": return DesignTokens.Colors.danger
        case "past": return .secondary
        default: return DesignTokens.Colors.accentSecondaryLight
        }
    }

    var placeLine: String? {
        if attendanceMode == "online" || (isOnline && latitude == nil && attendanceMode != "hybrid") {
            return "Online"
        }
        let parts = [venueName, address ?? locationName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var unique: [String] = []
        for part in parts where !unique.contains(part) { unique.append(part) }
        guard !unique.isEmpty else { return nil }
        let text = unique.joined(separator: ", ")
        return attendanceMode == "hybrid" ? "\(text) · also online" : text
    }

    var organizerLine: String? {
        if let organizerName, !organizerName.isEmpty { return "Hosted by \(organizerName)" }
        if let host { return "Hosted by \(host.name)" }
        return nil
    }

    var peopleLine: String? {
        if kind == "event" {
            var parts: [String] = []
            if let going = goingCount ?? attendeeCount, going > 0 { parts.append("\(going) going") }
            if let interested = interestedCount, interested > 0 { parts.append("\(interested) interested") }
            if let capacity {
                parts.append(isFull == true ? "Full (\(capacity) spots)" : "\(capacity) spots")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        if let memberCount { return "\(memberCount) \(memberCount == 1 ? "member" : "members")" }
        return nil
    }

    var participationLabel: String {
        switch kind {
        case "event": return isGoing ? "Going" : "RSVP"
        case "study_group": return isJoined ? "Leave group" : "Join group"
        default: return "Open"
        }
    }

    var metaLine: String {
        [
            distanceText,
            whenText,
            priceText,
            peopleLine,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    static func formattedDate(_ value: String?) -> String? {
        guard let date = CommunityDiscovery.parseDate(value) else { return nil }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }
}

// Small circular avatar: remote image when available, colored initials otherwise.
struct AvatarBubble: View {
    let name: String
    let url: String?
    var size: CGFloat = 40

    private var initials: String {
        String(name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased()
    }

    var body: some View {
        Group {
            if let url, let parsed = URL(string: url), !url.isEmpty {
                AsyncImage(url: parsed) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            DesignTokens.Colors.accent.opacity(0.2)
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.accent)
        }
    }
}

struct CommunityPersonSheet: View {
    let person: APISearchUser

    var body: some View {
        VStack(spacing: 18) {
            AvatarBubble(name: person.name ?? person.username ?? "Member", url: person.avatarURL, size: 88)
                .padding(.top, 36)
            Text(person.name ?? "Member").font(.title2.bold())
            if let username = person.username, !username.isEmpty {
                Text("@\(username)").foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.background)
    }
}
