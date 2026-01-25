import SwiftUI
import MapKit
import Combine
import CoreLocation

// MARK: - Models

struct CommunityItem: Identifiable, Equatable {
    let id: String
    let type: CommunityItemType
    let title: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let imageURL: String?
    let userAvatar: String?
    let timestamp: Date
    
    // For specific type handling
    var eventData: APIEducationalEvent?
    var groupData: APIStudyGroup?
    var listingData: APIMarketplaceListing?
    var lessonData: APIPrivateLesson? // NEW
    var centerData: APIEducationalCenter? // NEW
    
    static func == (lhs: CommunityItem, rhs: CommunityItem) -> Bool {
        return lhs.id == rhs.id
    }
}

enum CommunityItemType: String, CaseIterable, Identifiable {
    case all = "All"
    case event = "Events"
    case group = "Groups"
    case privateLesson = "Lessons" // NEW
    case educationalCenter = "Centers" // NEW
    case question = "Questions"
    case spot = "Spots"
    case marketplace = "Market"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .event: return "calendar"
        case .group: return "person.3.fill"
        case .privateLesson: return "graduationcap.fill"
        case .educationalCenter: return "building.columns.fill"
        case .question: return "bubble.left.and.bubble.right.fill"
        case .spot: return "mappin.and.ellipse"
        case .marketplace: return "tag.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .event: return .orange
        case .group: return .blue
        case .privateLesson: return .indigo
        case .educationalCenter: return .teal
        case .question: return .purple
        case .spot: return .green
        case .marketplace: return .pink
        }
    }
}

// MARK: - API Models (Matching Endpoint.swift)
// See Sources/Models/CommunityDTOs.swift for APIStudyGroup, APIEducationalEvent, etc.

// Beacon wrapper for map display (consolidated)
struct CommunityBeacon: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: CommunityItemType
    let title: String
    let subtitle: String?
}



// MARK: - ViewModel

@MainActor
class CommunityViewModel: ObservableObject {
    // UI State
    @Published var searchText: String = "" {
        didSet { updateBeacons() }
    }
    @Published var selectedFilter: CommunityItemType = .all {
        didSet { updateBeacons() }
    }
    @Published var currentFilter: CommunityFilter = .all
    @Published var viewMode: ViewMode = .map
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    enum ViewMode {
        case map
        case list
    }
    
    // Data State
    @Published var items: [CommunityItem] = [] {
        didSet { updateBeacons() }
    }
    @Published var filteredItems: [CommunityItem] = [] // NEW: For List View
    @Published var beacons: [CommunityBeacon] = []
    @Published var mapPins: [MapPin] = []  // For CommunityDockView compatibility
    
    // Map State
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default SF
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @Published var selectedPin: MapPin?  // For dock view selection tracking
    
    // Location Manager
    private let locationManager = CLLocationManager()
    
    // Repositories
    private let network = NetworkClient.shared
    
    init() {
        requestLocation()
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let loc = locationManager.location {
            region.center = loc.coordinate
            mapCameraPosition = .region(region)
            loadData()
        }
    }
    
    // MARK: - Operations
    
    func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                // Fetch data in parallel
                async let groupsTask = fetchStudyGroups()
                async let eventsTask = fetchEvents()
                async let listingsTask = fetchListings()
                // Mocking new types for now as endpoints might not be ready
                // async let lessonsTask = fetchPrivateLessons()
                // async let centersTask = fetchEducationalCenters()
                
                let (groups, events, listings) = try await (groupsTask, eventsTask, listingsTask)
                
                // Convert to unified items
                var newItems: [CommunityItem] = []
                
                // Process Groups
                newItems.append(contentsOf: groups.map { group in
                    CommunityItem(
                        id: String(group.id),
                        type: .group,
                        title: group.name,
                        subtitle: "\(group.memberCount) members • \(group.subject)",
                        coordinate: CLLocationCoordinate2D(latitude: group.lat ?? 0, longitude: group.lng ?? 0),
                        imageURL: nil,
                        userAvatar: group.host.avatar,
                        timestamp: group.nextSession ?? Date(),
                        groupData: group
                    )
                })
                
                // Process Events
                newItems.append(contentsOf: events.map { event in
                    CommunityItem(
                        id: String(event.id),
                        type: .event,
                        title: event.title,
                        subtitle: event.locationName,
                        coordinate: CLLocationCoordinate2D(latitude: event.lat ?? 0, longitude: event.lng ?? 0),
                        imageURL: event.imageURL,
                        userAvatar: event.organizerProfile?.avatar,
                        timestamp: event.date,
                        eventData: event
                    )
                })
                
                // Process Listings
                newItems.append(contentsOf: listings.map { listing in
                    CommunityItem(
                        id: String(listing.id),
                        type: .marketplace,
                        title: listing.title,
                        subtitle: "\(listing.currency)\(listing.price)",
                        coordinate: CLLocationCoordinate2D(latitude: listing.lat ?? 0, longitude: listing.lng ?? 0),
                        imageURL: listing.images.first,
                        userAvatar: listing.sellerAvatar,
                        timestamp: Date(), // Listings timestamp?
                        listingData: listing
                    )
                })
                
                // MOCK Private Lessons
                let mockLessons = [
                    CommunityItem(
                        id: "lesson-1",
                        type: .privateLesson,
                        title: "Piano Mastery",
                        subtitle: "with Hector • $50/hr",
                        coordinate: CLLocationCoordinate2D(latitude: region.center.latitude + 0.002, longitude: region.center.longitude + 0.002),
                        imageURL: nil,
                        userAvatar: nil,
                        timestamp: Date(),
                        lessonData: APIPrivateLesson(id: 1, title: "Piano Mastery", subject: "Music", instructor: APIUserPreview(id: 99, name: "Hector", avatar: nil), cost: 50, durationMinutes: 60, description: "Advanced piano techniques", lat: region.center.latitude + 0.002, lng: region.center.longitude + 0.002, imageURL: nil)
                    )
                ]
                newItems.append(contentsOf: mockLessons)
                
                // MOCK Educational Centers
                let mockCenters = [
                    CommunityItem(
                        id: "center-1",
                        type: .educationalCenter,
                        title: "City Library",
                        subtitle: "Library • Open 9AM-8PM",
                        coordinate: CLLocationCoordinate2D(latitude: region.center.latitude - 0.002, longitude: region.center.longitude - 0.002),
                        imageURL: nil,
                        userAvatar: nil,
                        timestamp: Date(),
                        centerData: APIEducationalCenter(id: 1, name: "City Library", category: "Library", description: "Main public library", lat: region.center.latitude - 0.002, lng: region.center.longitude - 0.002, imageURL: nil, address: "123 Main St", openingHours: "9AM-8PM")
                    )
                ]
                newItems.append(contentsOf: mockCenters)
                
                // Update Main Thread
                let finalItems = newItems
                await MainActor.run {
                    self.items = finalItems
                    self.updateBeacons()
                    self.isLoading = false
                }
                
            } catch {
                print("❌ Community Fetch Error: \(error.localizedDescription)")
                self.errorMessage = "Failed to load community data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func createPrivateLesson(_ lesson: APIPrivateLesson) async throws {
        // Mock success
        loadData()
    }
    
    func createEducationalCenter(_ center: APIEducationalCenter) async throws {
        // Mock success
        loadData()
    }
    
    private func updateBeacons() {
        // 1. Filter by Type
        var filtered = selectedFilter == .all ? items : items.filter { $0.type == selectedFilter }
        
        // 2. Filter by Search Text
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                (item.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        self.beacons = filtered.compactMap { item in
            // Only include items with valid coordinates
            guard item.coordinate.latitude != 0 && item.coordinate.longitude != 0 else { return nil }
            return CommunityBeacon(
                id: item.id,
                coordinate: item.coordinate,
                type: item.type,
                title: item.title,
                subtitle: item.subtitle
            )
        }
        // Also update the list view items if they are driven by a separate published property, 
        // but here CommunityListView seems to use `viewModel.items`. 
        // We should probably expose a `displayedItems` property for the list/map to share logic.
    }
    
    // MARK: - API Calls (Real Backend)
    
    private func fetchStudyGroups() async throws -> [APIStudyGroup] {
        return try await network.request(Endpoints.Community.getStudyGroups(filters: nil, location: region.center))
    }
    
    private func fetchEvents() async throws -> [APIEducationalEvent] {
        return try await network.request(Endpoints.Community.getEvents(filters: nil, location: region.center))
    }
    
    private func fetchListings() async throws -> [APIMarketplaceListing] {
        return try await network.request(Endpoints.Community.getListings(filters: nil, location: region.center))
    }
    
    // MARK: - Filter
    
    func applyFilter(_ filter: CommunityFilter) {
        currentFilter = filter
        updateBeacons()
        // Note: MapPins could be updated here if we tracked domain models
    }
    
    // MARK: - Actions
    
    func createEvent(_ event: EducationalEvent) async throws {
        // Implementation for creating event - endpoint now uses domain model
        let _: EducationalEvent = try await network.request(Endpoints.Community.createEvent(event: event))
        loadData() // Refresh
    }
    
    func createStudyGroup(_ group: StudyGroup) async throws {
        let _: StudyGroup = try await network.request(Endpoints.Community.createStudyGroup(group: group))
        loadData()
    }
    
    func createQuestion(content: String, tags: [String], isAnonymous: Bool) async throws {
        let request = APICreateQuestionRequest(
            content: content,
            tags: tags,
            lat: region.center.latitude,
            lng: region.center.longitude,
            isAnonymous: isAnonymous
        )
        let _: APIQuestionResponse = try await network.request(Endpoints.Community.createQuestion(question: request))
        loadData()
    }
    
    func joinStudyGroup(id: String) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.joinStudyGroup(groupId: id))
        loadData() // Refresh
    }
    
    func registerForEvent(id: String) async throws {
        let _: EmptyResponse = try await network.request(Endpoints.Community.registerForEvent(eventId: id))
        loadData()
    }
    
    func centerMapOnPin(_ pin: MapPin) {
        selectedPin = pin
        region.center = pin.coordinate
        mapCameraPosition = .region(MKCoordinateRegion(center: pin.coordinate, span: region.span))
    }
}
