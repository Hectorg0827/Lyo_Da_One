import SwiftUI
import MapKit

struct CommunityView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var selectedTab: CommunityTab = .aroundMe
    @State private var showCreateSheet = false

    enum CommunityTab: String, CaseIterable {
        case aroundMe = "Around Me"
        case mine = "My Community"
        case activity = "Activity"
    }

    var body: some View {
        NavigationStack {
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
                    LearningAroundMeView(viewModel: viewModel)
                case .mine:
                    MyCommunityAccountView(
                        viewModel: viewModel,
                        openSavedNode: { node in
                            viewModel.selectedNode = viewModel.nearbyNodes.first(where: { $0.key == node.key }) ?? node
                            selectedTab = .aroundMe
                        }
                    )
                case .activity:
                    CommunityFeedView()
                }
            }
            .background(DesignTokens.Colors.background)
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Create a learning node")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCommunityItemSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedPerson) { person in
            CommunityPersonSheet(person: person)
                .presentationDetents([.medium])
        }
        .alert("Community couldn't update", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
        .onAppear { viewModel.loadData() }
        .tint(DesignTokens.Colors.accent)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Learning Around Me

private struct LearningCategory: Identifiable {
    let id: String
    let title: String
    let icon: String

    static let all: [LearningCategory] = [
        .init(id: "event", title: "Events", icon: "calendar"),
        .init(id: "workshop", title: "Workshops", icon: "hammer.fill"),
        .init(id: "class", title: "Classes", icon: "graduationcap.fill"),
        .init(id: "study_group", title: "Study groups", icon: "person.3.fill"),
        .init(id: "tutor", title: "Tutors", icon: "person.crop.circle.badge.checkmark"),
        .init(id: "library", title: "Libraries", icon: "books.vertical.fill"),
        .init(id: "museum", title: "Museums", icon: "building.columns.fill"),
        .init(id: "educational_center", title: "Learning centers", icon: "building.2.fill"),
    ]
}

struct LearningAroundMeView: View {
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if viewModel.viewMode == .map {
                    LearningAroundMap(viewModel: viewModel)
                } else {
                    LearningAroundList(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                LearningAroundControls(viewModel: viewModel)
                Spacer()
            }

            if let node = viewModel.selectedNode {
                LearningNodeDrawer(
                    node: node,
                    busy: viewModel.busyNodeKey == node.key,
                    onClose: { viewModel.selectedNode = nil },
                    onSave: { Task { await viewModel.toggleSave(node) } },
                    onParticipate: { Task { await viewModel.toggleParticipation(node) } }
                )
                .padding(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.selectedNode?.key)
    }
}

private struct LearningAroundControls: View {
    @ObservedObject var viewModel: CommunityViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Libraries, classes, tutors, events…", text: $viewModel.searchText)
                        .focused($searchFocused)
                        .submitLabel(.search)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))

                Picker("View", selection: $viewModel.viewMode) {
                    Image(systemName: "map.fill").tag(CommunityViewModel.ViewMode.map)
                    Image(systemName: "list.bullet").tag(CommunityViewModel.ViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
            }

            HStack {
                Button { viewModel.centerOnUserLocation() } label: {
                    Label(viewModel.locationLabel, systemImage: "location.fill")
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))

                Spacer()

                Text("\(viewModel.visibleNodes.count) nearby")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CommunityFilterChip(
                        title: "All learning",
                        icon: "sparkles",
                        selected: viewModel.selectedCategories.isEmpty,
                        action: { viewModel.selectedCategories = [] }
                    )
                    ForEach(LearningCategory.all) { category in
                        CommunityFilterChip(
                            title: category.title,
                            icon: category.icon,
                            selected: viewModel.selectedCategories.contains(category.id),
                            action: {
                                if viewModel.selectedCategories.contains(category.id) {
                                    viewModel.selectedCategories.remove(category.id)
                                } else {
                                    viewModel.selectedCategories.insert(category.id)
                                }
                            }
                        )
                    }
                }
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
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? DesignTokens.Colors.accent : Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LearningAroundMap: View {
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        Map(position: $viewModel.mapCameraPosition) {
            UserAnnotation()
            ForEach(viewModel.mapNodes, id: \.key) { node in
                if let latitude = node.latitude, let longitude = node.longitude {
                    Annotation(node.title, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) {
                        Button { viewModel.selectedNode = node } label: {
                            LearningMapPin(node: node, selected: viewModel.selectedNode?.key == node.key)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(node.categoryLabel): \(node.title)")
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onMapCameraChange { context in viewModel.handleMapRegionChange(context.region) }
        .overlay {
            if viewModel.isLoading && viewModel.nearbyNodes.isEmpty {
                ProgressView("Finding learning nearby…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
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
                .frame(width: selected ? 40 : 34, height: selected ? 40 : 34)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.35), radius: 5, y: 3)
            Image(systemName: node.categoryIcon)
                .font(.system(size: selected ? 17 : 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

private struct LearningAroundList: View {
    @ObservedObject var viewModel: CommunityViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Color.clear.frame(height: viewModel.people.isEmpty ? 154 : 205)
                ForEach(viewModel.visibleNodes, id: \.key) { node in
                    LearningNodeRow(node: node) {
                        viewModel.selectedNode = node
                        viewModel.viewMode = .map
                        if let latitude = node.latitude, let longitude = node.longitude {
                            let region = MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                            )
                            viewModel.mapCameraPosition = .region(region)
                        }
                    }
                }
                if viewModel.visibleNodes.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No learning nodes here yet",
                        systemImage: "map",
                        description: Text("Try another filter or move the map to a new area.")
                    )
                    .padding(.top, 36)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 100)
        }
        .background(DesignTokens.Colors.background)
    }
}

private struct LearningNodeRow: View {
    let node: APILearningNode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: node.categoryIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(node.categoryColor)
                    .frame(width: 42, height: 42)
                    .background(node.categoryColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top) {
                        Text(node.title)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if node.isSaved { Image(systemName: "bookmark.fill").foregroundStyle(DesignTokens.Colors.accent) }
                    }
                    Text(node.metaLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    if let location = node.locationName, !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .background(DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}

private struct LearningNodeDrawer: View {
    let node: APILearningNode
    let busy: Bool
    let onClose: () -> Void
    let onSave: () -> Void
    let onParticipate: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: node.categoryIcon)
                    .foregroundStyle(node.categoryColor)
                    .frame(width: 40, height: 40)
                    .background(node.categoryColor.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.categoryLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(node.title).font(.headline)
                    Text(node.metaLine).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }

            if let description = node.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let location = node.locationName, !location.isEmpty {
                Label(location, systemImage: node.isOnline ? "video.fill" : "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if node.kind == "event" || node.kind == "study_group" {
                        Button(node.participationLabel, action: onParticipate)
                            .buttonStyle(.borderedProminent)
                            .disabled(busy)
                    }
                    Button(action: onSave) {
                        Label(node.isSaved ? "Saved" : "Save", systemImage: node.isSaved ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)

                    if let value = node.meetingUrl,
                       let url = URL(string: value),
                       url.scheme == "https" || url.scheme == "http" {
                        Button { openURL(url) } label: { Label("Join online", systemImage: "video.fill") }
                            .buttonStyle(.bordered)
                    }

                    if let courseId = node.courseId {
                        Button {
                            NotificationCenter.default.post(
                                name: .openClassroom,
                                object: nil,
                                userInfo: ["courseId": String(courseId), "courseTitle": node.title]
                            )
                        } label: {
                            Label("Course", systemImage: "graduationcap.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("TriggerLioChat"), object: nil)
                    } label: {
                        Label("Ask Lyo", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)

                    if let value = node.sourceUrl,
                       let url = URL(string: value),
                       url.scheme == "https" || url.scheme == "http" {
                        Button { openURL(url) } label: { Label("Details", systemImage: "safari") }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }
}

// MARK: - Account-owned Community

private struct MyCommunityAccountView: View {
    @ObservedObject var viewModel: CommunityViewModel
    let openSavedNode: (APILearningNode) -> Void

    var body: some View {
        ScrollView {
            if let account = viewModel.myCommunity {
                LazyVStack(alignment: .leading, spacing: 12) {
                    accountHeader
                    sectionTitle("Saved learning", icon: "bookmark.fill")
                    ForEach(account.savedNodes, id: \.key) { node in
                        LearningNodeRow(node: node) { openSavedNode(node) }
                    }
                    if account.savedNodes.isEmpty { empty("Save something on the map and it will appear here on every device.") }

                    sectionTitle("Joined groups", icon: "person.3.fill")
                    ForEach(account.joinedGroups) { group in
                        accountCard(
                            group.name,
                            subtitle: [group.memberCount.map { "\($0) members" }, group.isOnline ? "Online" : group.location]
                                .compactMap { $0 }.joined(separator: " · ")
                        )
                    }
                    if account.joinedGroups.isEmpty { empty("You haven't joined a study group yet.") }

                    sectionTitle("Your events", icon: "calendar")
                    ForEach(account.attendingEvents) { event in
                        accountCard(
                            event.title,
                            subtitle: [APILearningNode.formattedDate(event.startTime), event.isOnline ? "Online" : event.location]
                                .compactMap { $0 }.joined(separator: " · ")
                        )
                    }
                    if account.attendingEvents.isEmpty { empty("No upcoming events on this account.") }

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
            } else {
                ProgressView("Loading your Community…")
                    .padding(.top, 80)
            }
        }
        .refreshable { viewModel.loadData() }
        .background(DesignTokens.Colors.background)
    }

    private var accountHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("One Community, every device")
                .font(.headline)
            Text("Your saves, RSVPs, groups, and connections belong to your Lyo account—not this iPhone.")
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
    }

    private func accountCard(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
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
        LearningCategory.all.first(where: { $0.id == category })?.title ?? "Learning"
    }

    var categoryIcon: String {
        LearningCategory.all.first(where: { $0.id == category })?.icon ?? "mappin"
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
        default: return .indigo
        }
    }

    var participationLabel: String {
        switch kind {
        case "event": return isAttending ? "Leave event" : "RSVP"
        case "study_group": return isJoined ? "Leave group" : "Join group"
        default: return "Open"
        }
    }

    var metaLine: String {
        [
            distanceKm.map { String(format: "%.1f km", $0) },
            Self.formattedDate(startsAt),
            host.map { "by \($0.name)" },
            attendeeCount.map { "\($0) going" },
            memberCount.map { "\($0) members" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    static func formattedDate(_ value: String?) -> String? {
        guard let date = CommunityViewModel.parseDate(value) else { return nil }
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
