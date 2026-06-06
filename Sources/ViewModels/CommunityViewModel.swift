import SwiftUI
import MapKit
import Combine
import CoreLocation
import os

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
    var courseData: APISharedCourse? // NEW
    
    static func == (lhs: CommunityItem, rhs: CommunityItem) -> Bool {
        return lhs.id == rhs.id
    }
}

enum CommunityItemType: String, CaseIterable, Identifiable {
    case all = "All"
    case event = "Events"
    case group = "Groups"
    case privateLesson = "Lessons" 
    case educationalCenter = "Centers"
    case course = "Courses" // NEW
    case question = "Questions"
    case spot = "Spots"
    case marketplace = "Market"
    case school = "Schools"
    case library = "Libraries"
    case gym = "Health & Fitness"
    case placeOfWorship = "Places of Worship"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .event: return "calendar"
        case .group: return "person.3.fill"
        case .course: return "graduationcap.fill" // Icon for Courses
        case .privateLesson: return "person.badge.key.fill" // Re-using for Lessons
        case .educationalCenter: return "building.columns.fill"
        case .question: return "bubble.left.and.bubble.right.fill"
        case .spot: return "mappin.and.ellipse"
        case .marketplace: return "tag.fill"
        case .school: return "book.fill"
        case .library: return "books.vertical.fill"
        case .gym: return "figure.run"
        case .placeOfWorship: return "hands.sparkles.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .event: return .orange
        case .group: return .blue
        case .privateLesson: return .indigo
        case .educationalCenter: return .teal
        case .course: return .blue // Color for Courses
        case .question: return .purple
        case .spot: return .green
        case .marketplace: return .pink
        case .school: return .blue
        case .library: return .brown
        case .gym: return .green
        case .placeOfWorship: return .yellow
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
    let imageURL: String?
    let hasLinkedCourse: Bool
    var distance: Double?
}



// MARK: - ViewModel

@MainActor
class CommunityViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
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
    @Published var showNearbyPlaces: Bool = false {
        didSet {
            // Re-filter or reload data when toggle changes
            loadData()
        }
    }
    
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
    
    @Published var selectedPin: CommunityBeacon? {
        didSet {
            // When a pin is selected, ensure it's visible in the UI
            if let pin = selectedPin {
                 withAnimation {
                     region.center = pin.coordinate
                     // We intentionally don't change span to avoid zooming in too much automatically
                 }
            }
        }
    }
    
    // De-bouncer for map updates
    private var mapUpdateTask: Task<Void, Never>?
    
    // Location Manager
    private let locationManager = CLLocationManager()
    
    // Repositories
    private let network = NetworkClient.shared
    
    override init() {
        super.init()
        locationManager.delegate = self
        requestLocation()
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        if let loc = locationManager.location {
            region.center = loc.coordinate
            mapCameraPosition = .region(region)
            loadData()
            fetchRealWorldCenters()
        }
    }
    
    // Track map region changes to refresh real-world data
    // Track map region changes to refresh real-world data AND backend beacons
    func handleMapRegionChange(_ newRegion: MKCoordinateRegion) {
        // Debounce map updates
        mapUpdateTask?.cancel()
        mapUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s debounce
            
            // Only refresh if the change is significant (e.g. moved > 1km)
            let latDiff = abs(newRegion.center.latitude - region.center.latitude)
            let lonDiff = abs(newRegion.center.longitude - region.center.longitude)
            
            if latDiff > 0.005 || lonDiff > 0.005 {
                await MainActor.run {
                    self.region = newRegion
                    // Reload data for the new region
                    self.loadData()
                }
            }
        }
    }
    
    func centerOnUserLocation() {
        if let loc = locationManager.location {
            withAnimation(.spring()) {
                region.center = loc.coordinate
                mapCameraPosition = .region(MKCoordinateRegion(center: loc.coordinate, span: region.span))
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updates handled via manager.location access in main actor calls usually,
        // but we can trigger a refresh if needed.
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.social.error("Location Manager Error: \(error.localizedDescription)")
    }
    
    // MARK: - Operations
    
    func loadData() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            if viewMode == .map {
                // Optimized fetch for Map: Get Beacons + Real World
                let apiBeacons = await fetchBeacons()
                
                await MainActor.run {
                    self.beacons = apiBeacons.compactMap { self.mapBeaconToViewModel($0) }
                    
                    if showNearbyPlaces {
                        fetchRealWorldCenters()
                    }
                    self.isLoading = false
                }
            } else {
                // Full fetch for List Mode
                 await loadFullList()
            }
        }
    }
    
    private func loadFullList() async {
        // Parallel fetch from all community endpoints (each helper handles its own errors)
        async let groupsTask = fetchStudyGroups()
            async let eventsTask = fetchEvents()
            async let listingsTask = fetchListings()
            async let lessonsTask = fetchPrivateLessons()
            async let centersTask = fetchEducationalCenters()
            async let coursesTask = fetchSharedCourses() // NEW

            let (groups, events, listings, lessons, centers, courses) = await (groupsTask, eventsTask, listingsTask, lessonsTask, centersTask, coursesTask)

            // Clear and re-populate with Backend Data only
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
                    timestamp: Date(), 
                    listingData: listing
                )
            })
            
            // Process Private Lessons
            newItems.append(contentsOf: lessons.map { lesson in
                CommunityItem(
                    id: "lesson-\(lesson.id)",
                    type: .privateLesson,
                    title: lesson.title,
                    subtitle: "with \(lesson.instructor.name) • $\(lesson.cost)/hr",
                    coordinate: CLLocationCoordinate2D(latitude: lesson.lat ?? 0, longitude: lesson.lng ?? 0),
                    imageURL: lesson.imageURL,
                    userAvatar: lesson.instructor.avatar,
                    timestamp: Date(),
                    lessonData: lesson
                )
            })
            
            // Process Educational Centers
            newItems.append(contentsOf: centers.map { center in
                CommunityItem(
                    id: "center-\(center.id)",
                    type: .educationalCenter,
                    title: center.name,
                    subtitle: "\(center.category) • \(center.openingHours ?? "")",
                    coordinate: CLLocationCoordinate2D(latitude: center.lat, longitude: center.lng),
                    imageURL: center.imageURL,
                    userAvatar: nil,
                    timestamp: Date(),
                    centerData: center
                )
            })
            
            // Process Shared Courses (NEW)
            newItems.append(contentsOf: courses.map { course in
                CommunityItem(
                    id: "course-\(course.id)",
                    type: .course,
                    title: course.title,
                    subtitle: "by \(course.creator.name) • \(course.difficulty)",
                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), // Courses often global
                    imageURL: course.thumbnailURL,
                    userAvatar: course.creator.avatar,
                    timestamp: course.createdAt,
                    courseData: course
                )
            })
            
            await MainActor.run {
                self.items = newItems
                // Update beacons derived from items for consistency if switching views
                self.updateBeacons()
                self.isLoading = false
            }
        }
    func createPrivateLesson(_ lesson: APIPrivateLessonRequest) async throws {
        loadData()
    }
    
    func createEducationalCenter(_ center: APIInstitutionRequest) async throws {
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
        
        self.filteredItems = filtered
        
        self.beacons = filtered.compactMap { item -> CommunityBeacon? in
            // Only include items with valid coordinates
            guard item.coordinate.latitude != 0 && item.coordinate.longitude != 0 else { return nil }
            return CommunityBeacon(
                id: item.id,
                coordinate: item.coordinate,
                type: item.type,
                title: item.title,
                subtitle: item.subtitle,
                imageURL: item.imageURL,
                hasLinkedCourse: item.courseData != nil
            )
        }
        // Also update the list view items if they are driven by a separate published property, 
        // but here CommunityListView seems to use `viewModel.items`. 
        // We should probably expose a `displayedItems` property for the list/map to share logic.
    }
    
    // MARK: - API Calls (Real Backend)
    // Each fetch is resilient: returns [] on failure so one broken endpoint
    // doesn't prevent the rest of the community data from loading.
    
    private func fetchStudyGroups() async -> [APIStudyGroup] {
        do {
            return try await network.request(Endpoints.Community.getStudyGroups(filters: nil, location: region.center))
        } catch {
            Log.social.warning("Community: study-groups fetch failed – \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchEvents() async -> [APIEducationalEvent] {
        do {
            return try await network.request(Endpoints.Community.getEvents(filters: nil, location: region.center))
        } catch {
            Log.social.warning("Community: events fetch failed – \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchListings() async -> [APIMarketplaceListing] {
        do {
            return try await network.request(Endpoints.Community.getListings(filters: nil, location: region.center))
        } catch {
            Log.social.warning("Community: marketplace fetch failed – \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchPrivateLessons() async -> [APIPrivateLesson] {
        // Return empty for now as there's no plural endpoint, or implement correct fetch logic
        Log.social.info("Community: plural lessons fetch not implemented in backend")
        return []
    }
    
    private func fetchEducationalCenters() async -> [APIEducationalCenter] {
        do {
            return try await network.request(Endpoints.Community.getInstitutions(filters: nil, location: region.center))
        } catch {
            Log.social.warning("Community: institutions fetch failed – \(error.localizedDescription)")
            return []
        }
    }
    
    
    private func fetchBeacons() async -> [APIBeacon] {
        do {
            // Fetch beacons within ~50km radius of center (approx 0.5 deg)
            let beacons: [APIBeacon] = try await network.request(Endpoints.Community.getBeacons(
                lat: region.center.latitude,
                lng: region.center.longitude,
                radius: 50
            ))
            return beacons
        } catch {
            Log.social.warning("Community: beacons fetch failed – \(error.localizedDescription)")
            return []
        }
    }
    
    private func mapBeaconToViewModel(_ apiBeacon: APIBeacon) -> CommunityBeacon {
        let (lat, lng) = apiBeacon.coordinate
        let type: CommunityItemType
        var subtitle: String? = nil
        
        switch apiBeacon {
        case .event(let e):
            type = .event
            if let date = e.startTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                subtitle = formatter.string(from: date)
            }
        case .user:
            type = .group // Map users to generic group/person icon for now
            subtitle = "Active User"
        case .question:
            type = .question
            subtitle = "Question"
        case .marketplace(let m):
            type = .marketplace
            subtitle = "$\(m.price)"
        }
        
        return CommunityBeacon(
            id: apiBeacon.id,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            type: type,
            title: {
                 switch apiBeacon {
                 case .event(let b): return b.title
                 case .user(let b): return b.displayName
                 case .question(let b): return b.text
                 case .marketplace(let b): return b.title
                 }
            }(),
            subtitle: subtitle,
            imageURL: nil, // Beacons are lightweight, no images
            hasLinkedCourse: false
        )
    }

    private func fetchSharedCourses() async -> [APISharedCourse] {
        []
    }
    
    private func fetchRealWorldCenters() {
        let categories: [(String, CommunityItemType)] = [
            ("School", .school),
            ("University", .school),
            ("College", .school),
            ("Library", .library),
            ("Gym", .gym),
            ("Fitness", .gym),
            ("Church", .placeOfWorship),
            ("Mosque", .placeOfWorship),
            ("Synagogue", .placeOfWorship),
            ("Temple", .placeOfWorship),
            ("Community Center", .educationalCenter)
        ]
        
        for (query, type) in categories {
            performLocalSearch(query: query, type: type)
        }
    }
    
    private func performLocalSearch(query: String, type: CommunityItemType) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self, let response = response, error == nil else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let newSearchItems = response.mapItems.map { mapItem in
                    CommunityItem(
                        id: "poi-\(mapItem.name ?? UUID().uuidString)-\(mapItem.placemark.coordinate.latitude)",
                        type: type,
                        title: mapItem.name ?? query,
                        subtitle: mapItem.phoneNumber,
                        coordinate: mapItem.placemark.coordinate,
                        imageURL: nil,
                        userAvatar: nil,
                        timestamp: Date()
                    )
                }
                
                // Merge with existing items, avoiding duplicates
                var hasNewItems = false
                for item in newSearchItems {
                    if !self.items.contains(where: { $0.id == item.id }) {
                        self.items.append(item)
                        hasNewItems = true
                    }
                }
                
                if hasNewItems {
                    self.updateBeacons()
                }
            }
        }
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
    
    func createListing(title: String, description: String, price: Double, category: String, condition: String, imageUrls: [String] = []) async throws {
        loadData()
    }
    
    func uploadImages(_ imagesData: [Data]) async throws -> [String] {
        var urls: [String] = []
        let storage = StorageService()
        
        for data in imagesData {
            do {
                let response = try await storage.uploadAvatar(imageData: data) // Reusing uploadAvatar logic for generic upload for now
                if response.success {
                    urls.append(response.publicUrl)
                }
            } catch {
                Log.social.error("Image upload failed: \(error.localizedDescription)")
            }
        }
        return urls
    }
    
    func createQuestion(content: String, tags: [String], isAnonymous: Bool) async throws {
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
    
    func centerMapOnPin(_ pin: CommunityBeacon) {
        selectedPin = pin
        region.center = pin.coordinate
        mapCameraPosition = .region(MKCoordinateRegion(center: pin.coordinate, span: region.span))
    }
}

@MainActor
extension CommunityViewModel {
    var mapRegion: MKCoordinateRegion { region }
    var availableFilters: [CommunityFilter] { [.all, .studyGroups, .events, .marketplace, .institutions, .today, .free] }
    var activeFilters: [CommunityFilter] { [currentFilter] }
    var studyGroups: [StudyGroup] { [] }
    var events: [EducationalEvent] { [] }
    var listings: [MarketplaceListing] { [] }
    var institutions: [Institution] { [] }

    func startUpdatingLocation() {
        requestLocation()
    }

    func loadAllData() async {
        loadData()
    }

    func searchInstitutions(query: String) async {
        searchText = query
        performLocalSearch(query: query, type: .educationalCenter)
    }

    func centerMapOnUser() {
        centerOnUserLocation()
    }

    func centerMapOnPin(_ pin: MapPin) {
        region.center = pin.coordinate
        mapCameraPosition = .region(MKCoordinateRegion(center: pin.coordinate, span: region.span))
    }

    func getDirections(to coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    func joinStudyGroup(_ group: StudyGroup) async {
        try? await joinStudyGroup(id: group.id)
    }

    func registerForEvent(_ event: EducationalEvent) async {
        try? await registerForEvent(id: event.id)
    }

    func contactSeller(listing: MarketplaceListing) {
        Log.social.info("Contact seller tapped for listing \(listing.id)")
    }
}
