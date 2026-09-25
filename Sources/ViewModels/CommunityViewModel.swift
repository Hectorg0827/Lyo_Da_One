import SwiftUI
import MapKit
import Combine
import CoreLocation
import os

// MARK: - Compatibility models

// These adapters remain for older Community subviews that are still compiled,
// while the active screen renders the canonical APILearningNode contract.
struct CommunityItem: Identifiable, Equatable {
    let id: String
    let type: CommunityItemType
    let title: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let imageURL: String?
    let userAvatar: String?
    let timestamp: Date
    var eventData: APIEducationalEvent?
    var groupData: APIStudyGroup?

    static func == (lhs: CommunityItem, rhs: CommunityItem) -> Bool { lhs.id == rhs.id }
}

enum CommunityItemType: String, CaseIterable, Identifiable {
    case all = "All"
    case event = "Events"
    case group = "Groups"

    var id: String { rawValue }
    static var crossPlatformCases: [CommunityItemType] { allCases }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .event: return "calendar"
        case .group: return "person.3.fill"
        }
    }

    var color: Color {
        switch self {
        case .all: return .primary
        case .event: return .orange
        case .group: return .blue
        }
    }
}

struct APISearchUser: Codable, Identifiable, Equatable {
    let id: Int
    let username: String?
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, username, name
        case avatarURL = "avatar_url"
    }
}

struct APISearchResponse: Codable { let users: [APISearchUser]? }

struct CommunityBeacon: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: CommunityItemType
    let title: String
    let subtitle: String?
    let imageURL: String?
    let hasLinkedCourse: Bool
    var distance: Double?
}

// MARK: - Map-first Community state

/// Learning Around Me on iOS. Everything that belongs to the learner (saves,
/// RSVPs, groups, hosted events) is read from and written to the backend by
/// account; the device only keeps what is on screen right now. Location is an
/// ephemeral query input and is never stored.
@MainActor
final class CommunityViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum ViewMode { case map, list }
    enum LocationState: Equatable { case locating, granted, denied, unavailable }
    enum SheetDetent: Equatable { case collapsed, medium, expanded }

    // MARK: Search and filters

    /// What the learner is typing. Typing never loads the map; submitting does.
    @Published var searchText = "" {
        didSet { searchPeople() }
    }
    /// The topic applied to the current results ("" when none).
    @Published private(set) var activeQuery = ""
    @Published private(set) var isResolvingSearch = false
    @Published private(set) var activeFilters: Set<String> = []

    // MARK: Results

    @Published var viewMode: ViewMode = .map
    @Published private(set) var nearbyNodes: [APILearningNode] = []
    @Published private(set) var degradedSources: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoadedOnce = false
    @Published private(set) var loadError: CommunityDiscovery.FriendlyError?
    /// Set when the latest refresh failed and older results are still shown.
    @Published private(set) var staleSince: Date?

    // MARK: Account

    @Published private(set) var myCommunity: APICommunityMeResponse?
    @Published private(set) var isAccountLoading = false
    @Published private(set) var accountError: CommunityDiscovery.FriendlyError?
    @Published private(set) var busyNodeKeys: Set<String> = []
    @Published private(set) var details: [String: APILearningNodeDetail] = [:]
    /// Bumped after a create, edit, or delete so open detail screens re-read.
    @Published private(set) var revision = 0

    // MARK: Selection and sheet

    @Published var selectedNode: APILearningNode?
    @Published var clusterKeys: [String]?
    @Published var sheetDetent: SheetDetent = .collapsed
    @Published var people: [APISearchUser] = []
    @Published var selectedPerson: APISearchUser?
    /// A short confirmation or failure line shown as a toast.
    @Published var toastMessage: String?
    @Published var errorMessage: String?

    // MARK: Location and map

    @Published private(set) var locationState: LocationState = .locating
    @Published var locationNoticeDismissed = false
    @Published private(set) var locationLabel = CommunityDiscovery.defaultLabel
    @Published private(set) var searchedArea = CommunityDiscovery.SearchArea(
        latitude: CommunityDiscovery.defaultLatitude,
        longitude: CommunityDiscovery.defaultLongitude,
        radiusKm: CommunityDiscovery.defaultRadiusKm
    )
    @Published private(set) var showAreaSearch = false
    @Published var region = CommunityViewModel.region(
        latitude: CommunityDiscovery.defaultLatitude,
        longitude: CommunityDiscovery.defaultLongitude,
        radiusKm: CommunityDiscovery.defaultRadiusKm
    )
    @Published var mapCameraPosition: MapCameraPosition = .region(
        CommunityViewModel.region(
            latitude: CommunityDiscovery.defaultLatitude,
            longitude: CommunityDiscovery.defaultLongitude,
            radiusKm: CommunityDiscovery.defaultRadiusKm
        )
    )

    // Compatibility state for inactive legacy views.
    @Published var selectedFilter: CommunityItemType = .all
    @Published var currentFilter: CommunityFilter = .all
    @Published var items: [CommunityItem] = []
    @Published var filteredItems: [CommunityItem] = []
    @Published var beacons: [CommunityBeacon] = []
    @Published var selectedPin: CommunityBeacon?

    private let locationManager = CLLocationManager()
    private let network = NetworkClient.shared
    private var nearbyTask: Task<Void, Never>?
    private var accountTask: Task<Void, Never>?
    private var peopleSearchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var started = false
    private var userCoordinate: CLLocationCoordinate2D?
    private var moveToUserOnNextFix = true
    private var trackedPermissionDenied = false
    /// The viewport right after the last search, and what is visible now.
    private var visibleBaseline: CommunityDiscovery.SearchArea?
    private var baselineDeadline: Date?
    private var pendingVisibleArea: CommunityDiscovery.SearchArea?
    /// Session memory of recent answers so going back to an area is instant
    /// and a failed refresh can keep showing the last good results.
    private var resultCache: [CommunityNearbyParams: (response: APINearbyLearningResponse, savedAt: Date)] = [:]
    private static let freshInterval: TimeInterval = 60

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        SyncService.shared.events
            .filter { $0.eventType == "community_updated" || $0.eventType == "context_updated" }
            .sink { [weak self] _ in self?.loadData() }
            .store(in: &cancellables)
    }

    // MARK: - Derived state

    var filterQuery: CommunityDiscovery.FilterQuery {
        CommunityDiscovery.query(for: activeFilters)
    }

    var effectiveRadiusKm: Double {
        filterQuery.nearby ? min(searchedArea.radiusKm, CommunityDiscovery.nearbyRadiusKm) : searchedArea.radiusKm
    }

    /// Kept for older call sites; results are already filtered by the server.
    var visibleNodes: [APILearningNode] { nearbyNodes }

    var mapNodes: [APILearningNode] {
        nearbyNodes.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var listNodes: [APILearningNode] {
        guard let clusterKeys else { return nearbyNodes }
        return nearbyNodes.filter { clusterKeys.contains($0.key) }
    }

    var userLocation: CLLocationCoordinate2D? { userCoordinate }

    var resultsTitle: String {
        let place: String
        switch locationLabel {
        case "Near you": place = "near you"
        case "This area": place = "in this area"
        default: place = "around \(locationLabel)"
        }
        if isLoading && nearbyNodes.isEmpty { return "Finding learning \(place)…" }
        if clusterKeys != nil { return "\(listNodes.count) here" }
        if loadError != nil && nearbyNodes.isEmpty { return "Learning opportunities" }
        let count = nearbyNodes.count
        return "\(count) learning \(count == 1 ? "opportunity" : "opportunities") \(place)"
    }

    func isBusy(_ node: APILearningNode) -> Bool { busyNodeKeys.contains(node.key) }

    /// The freshest copy of a node this screen knows about.
    func current(_ node: APILearningNode) -> APILearningNode {
        if let detail = details[node.key] { return detail.node }
        if let match = nearbyNodes.first(where: { $0.key == node.key }) { return match }
        return node
    }

    // MARK: - Lifecycle

    /// First appearance: record the open, ask for location without blocking
    /// the map, and read the account.
    func start() {
        guard !started else { return }
        started = true
        track("community_opened", ["surface": "ios"])
        requestLocation(explicit: false)
        refreshAccount()
        // Never hold the map hostage to a permission prompt: show the fallback
        // area after a moment and move when (if) a location arrives.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self, !self.hasLoadedOnce, !self.isLoading else { return }
            self.loadNearby()
        }
    }

    /// Re-read everything: pull to refresh, returning to the app, or another
    /// device changed this account's Community.
    func loadData() {
        resultCache.removeAll()
        loadNearby(force: true)
        refreshAccount()
    }

    // MARK: - Location

    func requestLocation(explicit: Bool) {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if explicit {
                locationState = .locating
                moveToUserOnNextFix = true
            }
            locationManager.requestLocation()
        case .notDetermined:
            moveToUserOnNextFix = true
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            markLocationDenied()
        @unknown default:
            locationState = .unavailable
        }
    }

    /// The locate button: jump back to the learner, or ask for location.
    func centerOnUserLocation() {
        if let userCoordinate {
            moveTo(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude,
                   radiusKm: CommunityDiscovery.defaultRadiusKm, label: "Near you")
        } else {
            requestLocation(explicit: true)
        }
    }

    private func markLocationDenied() {
        locationState = .denied
        if !trackedPermissionDenied {
            trackedPermissionDenied = true
            track("community_location_permission_denied")
        }
        if !hasLoadedOnce && !isLoading { loadNearby() }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                self.locationManager.requestLocation()
            case .denied, .restricted:
                self.markLocationDenied()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.userCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            self.locationState = .granted
            guard self.moveToUserOnNextFix else { return }
            self.moveToUserOnNextFix = false
            self.moveTo(latitude: latitude, longitude: longitude,
                        radiusKm: CommunityDiscovery.defaultRadiusKm, label: "Near you")
            self.refreshAccount()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        Log.social.warning("Community location unavailable: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            if denied {
                self.markLocationDenied()
            } else if self.userCoordinate == nil {
                self.locationState = .unavailable
                if !self.hasLoadedOnce && !self.isLoading { self.loadNearby() }
            }
        }
    }

    // MARK: - Map area

    nonisolated static func region(latitude: Double, longitude: Double, radiusKm: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            latitudinalMeters: radiusKm * 1_600,
            longitudinalMeters: radiusKm * 1_600
        )
    }

    /// Move the map and search there (a place search, the locate button, …).
    func moveTo(latitude: Double, longitude: Double, radiusKm: Double, label: String) {
        let area = CommunityDiscovery.SearchArea(latitude: latitude, longitude: longitude, radiusKm: radiusKm)
        searchedArea = area
        locationLabel = label
        let target = Self.region(latitude: latitude, longitude: longitude, radiusKm: radiusKm)
        region = target
        mapCameraPosition = .region(target)
        // The camera settles on a viewport a little different from the one
        // requested (screen shape); that settled view becomes the baseline.
        visibleBaseline = CommunityDiscovery.area(
            centerLatitude: latitude,
            centerLongitude: longitude,
            latitudeDelta: target.span.latitudeDelta,
            longitudeDelta: target.span.longitudeDelta
        )
        baselineDeadline = Date().addingTimeInterval(2)
        pendingVisibleArea = nil
        showAreaSearch = false
        clusterKeys = nil
        loadNearby()
    }

    /// The camera finished moving. Panning never loads anything by itself; it
    /// only decides whether to offer "Search this area".
    func mapCameraChanged(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        let visible = CommunityDiscovery.area(
            centerLatitude: newRegion.center.latitude,
            centerLongitude: newRegion.center.longitude,
            latitudeDelta: newRegion.span.latitudeDelta,
            longitudeDelta: newRegion.span.longitudeDelta
        )
        if let deadline = baselineDeadline, Date() < deadline {
            visibleBaseline = visible
            baselineDeadline = nil
            showAreaSearch = false
            return
        }
        baselineDeadline = nil
        pendingVisibleArea = visible
        showAreaSearch = CommunityDiscovery.shouldOfferAreaSearch(searched: visibleBaseline, visible: visible)
    }

    /// Kept for older call sites.
    func handleMapRegionChange(_ newRegion: MKCoordinateRegion) { mapCameraChanged(newRegion) }

    func searchThisArea() {
        guard let visible = pendingVisibleArea else { return }
        track("community_search_area", ["radius_km": String(Int(visible.radiusKm.rounded()))])
        searchedArea = visible
        visibleBaseline = visible
        locationLabel = "This area"
        showAreaSearch = false
        selectedNode = nil
        clusterKeys = nil
        loadNearby()
    }

    /// Empty-state helper: look twice as far around the same center.
    func widenSearch() {
        moveTo(
            latitude: searchedArea.latitude,
            longitude: searchedArea.longitude,
            radiusKm: min(CommunityDiscovery.maxSearchRadiusKm, max(5, searchedArea.radiusKm * 2)),
            label: locationLabel
        )
    }

    /// A cluster marker: zoom in, or list the items when they share a spot.
    func openCluster(_ cluster: CommunityDiscovery.Cluster) {
        let latSpan = cluster.north - cluster.south
        let lngSpan = cluster.east - cluster.west
        if max(latSpan, lngSpan) < 0.0008 || region.span.latitudeDelta < 0.004 {
            selectedNode = nil
            clusterKeys = cluster.members.map(\.key)
            sheetDetent = .medium
            return
        }
        let target = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: cluster.latitude, longitude: cluster.longitude),
            span: MKCoordinateSpan(
                latitudeDelta: max(latSpan * 1.8, 0.004),
                longitudeDelta: max(lngSpan * 1.8, 0.004)
            )
        )
        withAnimation(.easeInOut(duration: 0.35)) { mapCameraPosition = .region(target) }
    }

    // MARK: - Search

    func submitSearch() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            clearSearch()
            return
        }
        isResolvingSearch = true
        selectedNode = nil
        clusterKeys = nil
        track("community_search", ["length": String(text.count)])
        let origin = searchedArea
        Task { [weak self] in
            guard let self else { return }
            do {
                let resolution: APISearchResolution = try await self.network.request(
                    Endpoints.Community.resolveSearch(query: text, lat: origin.latitude, lng: origin.longitude),
                    cachePolicy: .reloadIgnoringCache
                )
                if let place = resolution.place, resolution.intent == "place" || resolution.intent == "mixed" {
                    self.activeQuery = resolution.intent == "mixed" ? (resolution.topic ?? "") : ""
                    self.moveTo(
                        latitude: place.latitude,
                        longitude: place.longitude,
                        radiusKm: min(30, max(2, place.radiusKm)),
                        label: place.name
                    )
                } else {
                    self.activeQuery = (resolution.topic?.isEmpty == false ? resolution.topic : nil) ?? text
                    self.loadNearby()
                }
            } catch {
                // Resolution is a convenience; a plain topic search always works.
                self.activeQuery = text
                self.loadNearby()
            }
            self.isResolvingSearch = false
            self.sheetDetent = .medium
        }
    }

    func clearSearch() {
        searchText = ""
        people = []
        guard !activeQuery.isEmpty else { return }
        activeQuery = ""
        loadNearby()
    }

    func toggleFilter(_ id: String) {
        let turningOn = !activeFilters.contains(id)
        activeFilters = CommunityDiscovery.toggle(activeFilters, id)
        selectedNode = nil
        clusterKeys = nil
        if turningOn { track("community_filter_selected", ["filter": id]) }
        if id == "nearby", turningOn, let userCoordinate {
            moveTo(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude,
                   radiusKm: CommunityDiscovery.nearbyRadiusKm, label: "Near you")
        } else {
            loadNearby()
        }
    }

    func clearFilters() {
        guard !activeFilters.isEmpty else { return }
        activeFilters = []
        clusterKeys = nil
        loadNearby()
    }

    // MARK: - Loading

    func retry() { loadNearby(force: true) }

    func loadNearby(force: Bool = false) {
        let query = filterQuery
        let params = CommunityNearbyParams(
            latitude: searchedArea.latitude,
            longitude: searchedArea.longitude,
            radiusKm: effectiveRadiusKm,
            categories: query.categories,
            placeTypes: query.placeTypes,
            query: activeQuery.isEmpty ? nil : activeQuery,
            when: query.when,
            freeOnly: query.freeOnly
        )
        let cached = resultCache[params]
        if let cached {
            apply(cached.response)
            if !force && Date().timeIntervalSince(cached.savedAt) < Self.freshInterval {
                nearbyTask?.cancel()
                loadError = nil
                staleSince = nil
                isLoading = false
                return
            }
        }
        nearbyTask?.cancel()
        isLoading = true
        loadError = nil
        nearbyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response: APINearbyLearningResponse = try await self.network.request(
                    Endpoints.Community.discoverNearby(params: params),
                    cachePolicy: .reloadIgnoringCache
                )
                guard !Task.isCancelled else { return }
                self.remember(response, for: params)
                self.apply(response)
                self.staleSince = nil
            } catch {
                guard !Task.isCancelled else { return }
                Log.social.warning("Community nearby request failed: \(error.localizedDescription)")
                let friendly = CommunityDiscovery.friendlyError(error)
                self.loadError = friendly
                self.track("community_load_failed", ["reason": friendly == CommunityDiscovery.offlineError ? "offline" : "error"])
                if let cached {
                    self.staleSince = cached.savedAt
                } else {
                    self.nearbyNodes = []
                    self.rebuildCompatibilityState()
                }
            }
            self.hasLoadedOnce = true
            self.isLoading = false
        }
    }

    private func remember(_ response: APINearbyLearningResponse, for params: CommunityNearbyParams) {
        if resultCache.count >= 24,
           let oldest = resultCache.min(by: { $0.value.savedAt < $1.value.savedAt })?.key {
            resultCache.removeValue(forKey: oldest)
        }
        resultCache[params] = (response, Date())
    }

    private func apply(_ response: APINearbyLearningResponse) {
        nearbyNodes = response.items
        degradedSources = response.degradedSources ?? []
        hasLoadedOnce = true
        if let selectedNode, let refreshed = response.items.first(where: { $0.key == selectedNode.key }) {
            self.selectedNode = refreshed
        }
        rebuildCompatibilityState()
    }

    func refreshAccount() {
        accountTask?.cancel()
        accountTask = Task { [weak self] in
            await self?.reloadAccount()
        }
    }

    func reloadAccount() async {
        isAccountLoading = true
        do {
            let response: APICommunityMeResponse = try await network.request(
                Endpoints.Community.getMyCommunityNear(lat: userCoordinate?.latitude, lng: userCoordinate?.longitude),
                cachePolicy: .reloadIgnoringCache
            )
            guard !Task.isCancelled else { return }
            myCommunity = response
            accountError = nil
        } catch {
            guard !Task.isCancelled else { return }
            Log.social.warning("Community account refresh failed: \(error.localizedDescription)")
            accountError = CommunityDiscovery.friendlyError(error, action: "load your Community")
        }
        isAccountLoading = false
    }

    // MARK: - Selection

    func select(_ node: APILearningNode) {
        selectedNode = node
        sheetDetent = .medium
        track("community_marker_opened", ["kind": node.kind, "category": node.category])
        if let latitude = node.latitude, let longitude = node.longitude,
           !regionContains(latitude: latitude, longitude: longitude) {
            var target = region
            target.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            withAnimation(.easeInOut(duration: 0.3)) { mapCameraPosition = .region(target) }
        }
    }

    private func regionContains(latitude: Double, longitude: Double) -> Bool {
        abs(latitude - region.center.latitude) < region.span.latitudeDelta / 2 &&
            abs(longitude - region.center.longitude) < region.span.longitudeDelta / 2
    }

    func closePreview() { selectedNode = nil }

    // MARK: - Detail

    func loadDetail(_ route: CommunityNodeRoute) async throws -> APILearningNodeDetail {
        let detail: APILearningNodeDetail = try await network.request(
            Endpoints.Community.learningNodeDetail(
                kind: route.kind,
                id: route.id,
                lat: userCoordinate?.latitude,
                lng: userCoordinate?.longitude
            ),
            cachePolicy: .reloadIgnoringCache
        )
        details[detail.node.key] = detail
        patchNode(key: detail.node.key) { $0 = Self.merge(detail.node, into: $0) }
        track(detail.node.kind == "event" ? "community_event_opened" : "community_place_opened",
              ["kind": detail.node.kind, "category": detail.node.category])
        return detail
    }

    func cachedDetail(_ route: CommunityNodeRoute) -> APILearningNodeDetail? {
        details[route.key]
    }

    // MARK: - Save, RSVP, join (optimistic, confirmed by the server)

    func toggleSave(_ node: APILearningNode) async {
        let node = current(node)
        let saving = !node.isSaved
        track("community_event_saved", ["kind": node.kind, "saved": saving ? "true" : "false"])
        await runOptimistic(
            node,
            verb: saving ? "save this" : "remove this from your saved items",
            success: saving ? "Saved to your Lyo account" : "Removed from saved",
            optimistic: { $0.isSaved = saving }
        ) {
            if saving {
                let _: APILearningNode = try await self.network.request(
                    Endpoints.Community.saveLearningNode(kind: node.kind, id: node.id, snapshot: node),
                    cachePolicy: .reloadIgnoringCache
                )
            } else {
                let _: EmptyResponse = try await self.network.request(
                    Endpoints.Community.unsaveLearningNode(kind: node.kind, id: node.id),
                    cachePolicy: .reloadIgnoringCache
                )
            }
            return nil
        }
    }

    /// `status` is "going", "interested", or nil to remove the RSVP.
    func setRSVP(_ node: APILearningNode, status: String?) async {
        let node = current(node)
        guard node.kind == "event" else { return }
        track("community_event_rsvp", ["status": status ?? "none"])
        let optimistic = CommunityDiscovery.applyingRSVP(status, to: node)
        let success: String
        switch status {
        case "going": success = "You're going"
        case "interested": success = "Marked as interested"
        default: success = "RSVP removed"
        }
        await runOptimistic(node, verb: "update your RSVP", success: success, optimistic: { $0 = Self.merge(optimistic, into: $0) }) {
            if let status {
                let confirmed: APILearningNode = try await self.network.request(
                    Endpoints.Community.setEventRSVP(eventId: node.id, status: status),
                    cachePolicy: .reloadIgnoringCache
                )
                return confirmed
            }
            let _: EmptyResponse = try await self.network.request(
                Endpoints.Community.clearEventRSVP(eventId: node.id),
                cachePolicy: .reloadIgnoringCache
            )
            return nil
        }
    }

    func toggleMembership(_ node: APILearningNode) async {
        let node = current(node)
        guard node.kind == "study_group" else { return }
        let joining = !node.isJoined
        await runOptimistic(
            node,
            verb: joining ? "join this group" : "leave this group",
            success: joining ? "You joined the group" : "You left the group",
            optimistic: {
                $0.isJoined = joining
                $0.memberCount = max(0, ($0.memberCount ?? 0) + (joining ? 1 : -1))
            }
        ) {
            if joining {
                let _: EmptyResponse = try await self.network.request(
                    Endpoints.Community.joinStudyGroup(groupId: node.id), cachePolicy: .reloadIgnoringCache)
            } else {
                let _: EmptyResponse = try await self.network.request(
                    Endpoints.Community.leaveStudyGroup(groupId: node.id), cachePolicy: .reloadIgnoringCache)
            }
            return nil
        }
    }

    /// Older map drawer entry point: RSVP "going" or join/leave.
    func toggleParticipation(_ node: APILearningNode) async {
        let node = current(node)
        switch node.kind {
        case "event": await setRSVP(node, status: node.rsvpStatus == "going" || node.isAttending ? nil : "going")
        case "study_group": await toggleMembership(node)
        default: break
        }
    }

    /// The UI changes at once; the server's answer then replaces the guess
    /// (so counts match every other device), and a failure puts it back.
    private func runOptimistic(
        _ node: APILearningNode,
        verb: String,
        success: String,
        optimistic: (inout APILearningNode) -> Void,
        action: @escaping () async throws -> APILearningNode?
    ) async {
        guard !busyNodeKeys.contains(node.key) else { return }
        busyNodeKeys.insert(node.key)
        let before = node
        patchNode(key: node.key, optimistic)
        do {
            let confirmed = try await action()
            if let confirmed {
                patchNode(key: node.key) { $0 = Self.merge(confirmed, into: $0) }
            }
            resultCache.removeAll()
            showToast(success)
            await reloadAccount()
        } catch {
            patchNode(key: node.key) { $0 = Self.restoringParticipation(from: before, into: $0) }
            Log.social.warning("Community action failed: \(error.localizedDescription)")
            showToast(CommunityDiscovery.friendlyError(error, action: verb).message)
        }
        busyNodeKeys.remove(node.key)
    }

    /// Apply `transform` to every on-screen copy of a node.
    private func patchNode(key: String, _ transform: (inout APILearningNode) -> Void) {
        if let index = nearbyNodes.firstIndex(where: { $0.key == key }) { transform(&nearbyNodes[index]) }
        if selectedNode?.key == key, var selected = selectedNode {
            transform(&selected)
            selectedNode = selected
        }
        if var detail = details[key] {
            transform(&detail.node)
            details[key] = detail
        }
        if var account = myCommunity {
            Self.apply(transform, key: key, to: &account.savedNodes)
            if var hosting = account.hosting {
                Self.apply(transform, key: key, to: &hosting)
                account.hosting = hosting
            }
            if var going = account.going {
                Self.apply(transform, key: key, to: &going)
                account.going = going
            }
            if var interested = account.interested {
                Self.apply(transform, key: key, to: &interested)
                account.interested = interested
            }
            myCommunity = account
        }
    }

    private static func apply(
        _ transform: (inout APILearningNode) -> Void,
        key: String,
        to nodes: inout [APILearningNode]
    ) {
        for index in nodes.indices where nodes[index].key == key {
            transform(&nodes[index])
        }
    }

    /// A server copy wins, except for the viewer-relative distance it may omit.
    nonisolated static func merge(_ incoming: APILearningNode, into existing: APILearningNode) -> APILearningNode {
        var merged = incoming
        if merged.distanceKm == nil { merged.distanceKm = existing.distanceKm }
        return merged
    }

    nonisolated static func restoringParticipation(from before: APILearningNode, into node: APILearningNode) -> APILearningNode {
        var restored = node
        restored.isSaved = before.isSaved
        restored.isJoined = before.isJoined
        restored.isAttending = before.isAttending
        restored.rsvpStatus = before.rsvpStatus
        restored.goingCount = before.goingCount
        restored.interestedCount = before.interestedCount
        restored.memberCount = before.memberCount
        restored.attendeeCount = before.attendeeCount
        return restored
    }

    // MARK: - Create, edit, delete, report

    @discardableResult
    func createEvent(request: APICreateEducationalEventRequest) async throws -> APICommunityEventRecord {
        let record: APICommunityEventRecord = try await network.request(
            Endpoints.Community.createEventRequest(request: request),
            cachePolicy: .reloadIgnoringCache
        )
        track("community_event_created", [
            "event_type": request.eventType,
            "mode": request.attendanceMode ?? (request.isOnline ? "online" : "in_person"),
            "visibility": request.visibility ?? "public",
        ])
        afterEventChange()
        return record
    }

    @discardableResult
    func updateEvent(id: Int, request: APIUpdateEventRequest) async throws -> APICommunityEventRecord {
        let record: APICommunityEventRecord = try await network.request(
            Endpoints.Community.updateEvent(eventId: String(id), request: request),
            cachePolicy: .reloadIgnoringCache
        )
        track("community_event_updated", ["event_type": record.eventType, "visibility": record.visibility ?? "public"])
        afterEventChange()
        return record
    }

    /// The host calls an event off: attendees keep seeing it, as cancelled.
    func cancelEvent(id: Int) async {
        do {
            try await updateEvent(id: id, request: APIUpdateEventRequest(status: "cancelled"))
            showToast("Event cancelled. Attendees will see it as cancelled.")
        } catch {
            showToast(CommunityDiscovery.friendlyError(error, action: "cancel this event").message)
        }
    }

    func deleteEvent(id: Int) async throws {
        let _: EmptyResponse = try await network.request(
            Endpoints.Community.deleteEvent(eventId: String(id)),
            cachePolicy: .reloadIgnoringCache
        )
        track("community_event_deleted")
        let key = "event:\(id)"
        details.removeValue(forKey: key)
        nearbyNodes.removeAll { $0.key == key }
        if selectedNode?.key == key { selectedNode = nil }
        showToast("Event deleted")
        afterEventChange()
    }

    func reportEvent(_ node: APILearningNode, reason: String, note: String?) async {
        track("community_event_reported", ["reason": reason])
        do {
            let response: APIEventReportResponse = try await network.request(
                Endpoints.Community.reportEvent(
                    eventId: node.id,
                    request: APIEventReportRequest(reason: reason, description: note)
                ),
                cachePolicy: .reloadIgnoringCache
            )
            showToast(response.message)
        } catch {
            showToast(CommunityDiscovery.friendlyError(error, action: "send your report").message)
        }
    }

    private func afterEventChange() {
        revision += 1
        resultCache.removeAll()
        loadNearby(force: true)
        refreshAccount()
    }

    func createStudyGroup(request: APICreateStudyGroupRequest) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createStudyGroupRequest(request: request))
        afterEventChange()
    }

    func createPrivateLesson(request: APICreatePrivateLessonRequest) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createPrivateLesson(request: request))
        afterEventChange()
    }

    /// Address suggestions for the event location picker, biased to the map.
    func geocode(_ query: String) async throws -> [APIPlaceSuggestion] {
        try await network.request(
            Endpoints.Community.geocode(query: query, lat: searchedArea.latitude, lng: searchedArea.longitude),
            cachePolicy: .reloadIgnoringCache
        )
    }

    // Legacy overloads used by older detail screens.
    func createEvent(_ event: EducationalEvent) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createEvent(event: event))
        afterEventChange()
    }

    func createStudyGroup(_ group: StudyGroup) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createStudyGroup(group: group))
        afterEventChange()
    }

    func joinStudyGroup(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.joinStudyGroup(groupId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { loadData() }
    }

    func leaveStudyGroup(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.leaveStudyGroup(groupId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { loadData() }
    }

    func registerForEvent(id: String, refresh: Bool = true) async throws {
        let _: APILearningNode = try await network.request(
            Endpoints.Community.setEventRSVP(eventId: id, status: "going"), cachePolicy: .reloadIgnoringCache)
        if refresh { loadData() }
    }

    func unregisterFromEvent(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(
            Endpoints.Community.clearEventRSVP(eventId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { loadData() }
    }

    func applyFilter(_ filter: CommunityFilter) { currentFilter = filter }

    func centerMapOnPin(_ pin: CommunityBeacon) {
        selectedPin = pin
        region.center = pin.coordinate
        mapCameraPosition = .region(region)
    }

    // MARK: - Feedback and analytics

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.toastMessage = nil
        }
    }

    /// Privacy-respecting product analytics: an allow-listed event name and a
    /// few small properties. Never a location, never blocking the UI.
    func track(_ name: String, _ properties: [String: String] = [:]) {
        let event = APICommunityAnalyticsEvent(name: name, platform: "ios", properties: properties)
        let network = network
        Task.detached(priority: .utility) {
            do {
                let _: EmptyResponse = try await network.request(
                    Endpoints.Community.trackAnalytics(event: event),
                    cachePolicy: .reloadIgnoringCache
                )
            } catch {
                // Analytics never interrupts learning.
            }
        }
    }

    // MARK: - Compatibility

    private func rebuildCompatibilityState() {
        items = nearbyNodes.map { node in
            let type: CommunityItemType = node.kind == "study_group" ? .group : .event
            return CommunityItem(
                id: node.id,
                type: type,
                title: node.title,
                subtitle: node.locationName,
                coordinate: CLLocationCoordinate2D(
                    latitude: node.latitude ?? 0,
                    longitude: node.longitude ?? 0
                ),
                imageURL: node.imageUrl,
                userAvatar: node.host?.avatar,
                timestamp: Self.parseDate(node.startsAt) ?? Date(),
                eventData: nil,
                groupData: nil
            )
        }
        filteredItems = items
        beacons = nearbyNodes.compactMap { node in
            guard let latitude = node.latitude, let longitude = node.longitude else { return nil }
            return CommunityBeacon(
                id: node.key,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                type: node.kind == "study_group" ? .group : .event,
                title: node.title,
                subtitle: node.locationName,
                imageURL: node.imageUrl,
                hasLinkedCourse: node.courseId != nil,
                distance: node.distanceKm.map { $0 * 0.621371 }
            )
        }
    }

    private func searchPeople() {
        peopleSearchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            people = []
            return
        }
        peopleSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            do {
                let response: APISearchResponse = try await self.network.request(
                    Endpoints.Search.search(query: query, type: "users", limit: 6, offset: 0)
                )
                if !Task.isCancelled { self.people = response.users ?? [] }
            } catch {
                Log.social.warning("Community people search failed: \(error.localizedDescription)")
            }
        }
    }

    nonisolated static func parseDate(_ value: String?) -> Date? {
        CommunityDiscovery.parseDate(value)
    }
}
