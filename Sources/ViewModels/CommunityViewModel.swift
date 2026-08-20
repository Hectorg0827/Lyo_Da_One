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

@MainActor
final class CommunityViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum ViewMode { case map, list }

    @Published var searchText = "" {
        didSet {
            scheduleNearbyRefresh()
            searchPeople()
        }
    }
    @Published var selectedCategories: Set<String> = [] {
        didSet { scheduleNearbyRefresh() }
    }
    @Published var viewMode: ViewMode = .map
    @Published var nearbyNodes: [APILearningNode] = []
    @Published var myCommunity: APICommunityMeResponse?
    @Published var selectedNode: APILearningNode?
    @Published var people: [APISearchUser] = []
    @Published var selectedPerson: APISearchUser?
    @Published var isLoading = false
    @Published var isAccountLoading = false
    @Published var busyNodeKey: String?
    @Published var errorMessage: String?
    @Published var locationLabel = "New York City"

    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
    )
    @Published var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
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
    private var refreshTask: Task<Void, Never>?
    private var peopleSearchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var hasAppliedDeviceLocation = false

    override init() {
        super.init()
        locationManager.delegate = self
        SyncService.shared.events
            .filter { $0.eventType == "community_updated" || $0.eventType == "context_updated" }
            .sink { [weak self] _ in self?.loadData() }
            .store(in: &cancellables)
        requestLocation()
    }

    var visibleNodes: [APILearningNode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return nearbyNodes.filter { node in
            (selectedCategories.isEmpty || selectedCategories.contains(node.category)) &&
            (query.isEmpty || node.title.localizedCaseInsensitiveContains(query) ||
             (node.description?.localizedCaseInsensitiveContains(query) ?? false) ||
             (node.locationName?.localizedCaseInsensitiveContains(query) ?? false))
        }
    }

    var mapNodes: [APILearningNode] {
        visibleNodes.filter { $0.latitude != nil && $0.longitude != nil }
    }

    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            loadData()
        }
    }

    func centerOnUserLocation() {
        guard let location = locationManager.location else {
            requestLocation()
            return
        }
        applyDeviceLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            } else if manager.authorizationStatus != .notDetermined {
                self.loadData()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude
        let longitude = coordinate.longitude
        Task { @MainActor [weak self] in
            guard let self, !self.hasAppliedDeviceLocation else { return }
            self.hasAppliedDeviceLocation = true
            manager.stopUpdatingLocation()
            self.applyDeviceLocation(latitude: latitude, longitude: longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.social.warning("Community location unavailable: \(error.localizedDescription)")
        Task { @MainActor [weak self] in self?.loadData() }
    }

    private func applyDeviceLocation(latitude: Double, longitude: Double) {
        region.center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapCameraPosition = .region(region)
        locationLabel = "Current location"
        loadData()
    }

    func handleMapRegionChange(_ newRegion: MKCoordinateRegion) {
        let latDifference = abs(newRegion.center.latitude - region.center.latitude)
        let lngDifference = abs(newRegion.center.longitude - region.center.longitude)
        region = newRegion
        guard latDifference > 0.01 || lngDifference > 0.01 else { return }
        locationLabel = "Map area"
        scheduleNearbyRefresh(delayNanoseconds: 700_000_000)
    }

    func loadData() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshAll()
        }
    }

    private func scheduleNearbyRefresh(delayNanoseconds: UInt64 = 300_000_000) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            await self.refreshNearby()
        }
    }

    private func refreshAll() async {
        await refreshNearby()
        await refreshAccount()
    }

    private func refreshNearby() async {
        isLoading = true
        do {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let response: APINearbyLearningResponse = try await network.request(
                Endpoints.Community.nearbyLearning(
                    lat: region.center.latitude,
                    lng: region.center.longitude,
                    radius: 20,
                    categories: Array(selectedCategories),
                    query: query.isEmpty ? nil : query
                ),
                cachePolicy: .reloadIgnoringCache
            )
            nearbyNodes = response.items
            if let selectedNode,
               let refreshed = response.items.first(where: { $0.key == selectedNode.key }) {
                self.selectedNode = refreshed
            }
            rebuildCompatibilityState()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            Log.social.warning("Community nearby refresh failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func refreshAccount() async {
        isAccountLoading = true
        do {
            let response: APICommunityMeResponse = try await network.request(
                Endpoints.Community.getMyCommunity,
                cachePolicy: .reloadIgnoringCache
            )
            myCommunity = response
            if let selectedNode,
               !nearbyNodes.contains(where: { $0.key == selectedNode.key }) {
                self.selectedNode = response.savedNodes.first(where: { $0.key == selectedNode.key })
            }
        } catch {
            Log.social.warning("Community account refresh failed: \(error.localizedDescription)")
        }
        isAccountLoading = false
    }

    func toggleSave(_ node: APILearningNode) async {
        await perform(node: node) {
            if node.isSaved {
                let _: EmptyResponse = try await self.network.request(
                    Endpoints.Community.unsaveLearningNode(kind: node.kind, id: node.id),
                    cachePolicy: .reloadIgnoringCache
                )
            } else {
                let _: APILearningNode = try await self.network.request(
                    Endpoints.Community.saveLearningNode(kind: node.kind, id: node.id, snapshot: node),
                    cachePolicy: .reloadIgnoringCache
                )
            }
        }
    }

    func toggleParticipation(_ node: APILearningNode) async {
        await perform(node: node) {
            switch node.kind {
            case "event":
                if node.isAttending { try await self.unregisterFromEvent(id: node.id, refresh: false) }
                else { try await self.registerForEvent(id: node.id, refresh: false) }
            case "study_group":
                if node.isJoined { try await self.leaveStudyGroup(id: node.id, refresh: false) }
                else { try await self.joinStudyGroup(id: node.id, refresh: false) }
            default:
                break
            }
        }
    }

    private func perform(node: APILearningNode, operation: @escaping () async throws -> Void) async {
        guard busyNodeKey == nil else { return }
        busyNodeKey = node.key
        do {
            try await operation()
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        busyNodeKey = nil
    }

    func createEvent(request: APICreateEducationalEventRequest) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createEventRequest(request: request))
        await refreshAll()
    }

    func createStudyGroup(request: APICreateStudyGroupRequest) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createStudyGroupRequest(request: request))
        await refreshAll()
    }

    func createPrivateLesson(request: APICreatePrivateLessonRequest) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createPrivateLesson(request: request))
        await refreshAll()
    }

    // Legacy overloads used by older detail screens.
    func createEvent(_ event: EducationalEvent) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createEvent(event: event))
        await refreshAll()
    }

    func createStudyGroup(_ group: StudyGroup) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.createStudyGroup(group: group))
        await refreshAll()
    }

    func joinStudyGroup(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.joinStudyGroup(groupId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { await refreshAll() }
    }

    func leaveStudyGroup(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.leaveStudyGroup(groupId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { await refreshAll() }
    }

    func registerForEvent(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.registerForEvent(eventId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { await refreshAll() }
    }

    func unregisterFromEvent(id: String, refresh: Bool = true) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.unregisterFromEvent(eventId: id), cachePolicy: .reloadIgnoringCache)
        if refresh { await refreshAll() }
    }

    func applyFilter(_ filter: CommunityFilter) { currentFilter = filter }

    func centerMapOnPin(_ pin: CommunityBeacon) {
        selectedPin = pin
        region.center = pin.coordinate
        mapCameraPosition = .region(region)
    }

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
        beacons = visibleNodes.compactMap { node in
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
            try? await Task.sleep(nanoseconds: 250_000_000)
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

    static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        if let date = ISO8601DateFormatter().date(from: value) { return date }

        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return local.date(from: value)
    }
}
