import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Community ViewModel
@MainActor
class CommunityViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties
    
    // Community
    @Published var studyGroups: [StudyGroup] = []
    @Published var events: [EducationalEvent] = []
    @Published var listings: [MarketplaceListing] = []
    @Published var institutions: [Institution] = []
    
    // Library (New)
    @Published var featuredContent: [ContentItem] = []
    @Published var quickWins: [ContentItem] = [] // Micro-lessons
    @Published var learningPaths: [ContentItem] = [] // Paths
    @Published var trendingContent: [ContentItem] = [] // Mini-courses
    @Published var allContent: [ContentItem] = []

    // UI State
    @Published var selectedMode: CampusViewMode = .library // Default to Library!
    @Published var searchQuery = ""
    @Published var selectedTypeFilter: CampusItemType?
    @Published var errorMessage: String?

    @Published var mapPins: [MapPin] = []
    @Published var selectedPin: MapPin?
    @Published var activeFilters: Set<CommunityFilter> = [.all]

    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default: San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isLoadingLocation = false
    @Published var isLoadingData = false
    @Published var error: LyoError?
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Dependencies

    private let repository: CommunityRepository
    private let contentRepository: ContentRepository
    private let locationManager: CLLocationManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: CommunityRepository = DefaultCommunityRepository(),
         contentRepository: ContentRepository = DefaultContentRepository()) {
        self.repository = repository
        self.contentRepository = contentRepository
        self.locationManager = CLLocationManager()
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationPermissionStatus = locationManager.authorizationStatus
        
        Task {
            await loadAllData()
        }
    }

    // MARK: - Location Services

    func requestLocationPermission() {
        isLoadingLocation = true
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }

        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Data Loading

    func loadAllData() async {
        isLoadingData = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            // Library
            group.addTask { await self.loadLibraryData() }
            
            // Community
            group.addTask { await self.loadStudyGroups() }
            group.addTask { await self.loadEvents() }
            group.addTask { await self.loadListings() }
            group.addTask { await self.loadInstitutions() }
        }

        updateMapPins()
        isLoadingData = false
    }
    
    func loadLibraryData() async {
        do {
            async let featured = contentRepository.getFeaturedContent()
            async let quick = contentRepository.getQuickWins()
            async let paths = contentRepository.getLearningPaths()
            async let trending = contentRepository.getTrendingMiniCourses()
            async let all = contentRepository.getAllContent()
            
            self.featuredContent = try await featured
            self.quickWins = try await quick
            self.learningPaths = try await paths
            self.trendingContent = try await trending
            self.allContent = try await all
        } catch {
            print("Error loading library content: \(error)")
            // Don't block UI, just log
        }
    }

    func loadStudyGroups() async {
        do {
            let filters = getActiveFilter()
            studyGroups = try await repository.getStudyGroups(filters: filters, location: userLocation)
            calculateDistances(for: studyGroups)
        } catch {
            handleError(error)
        }
    }

    func loadEvents() async {
        do {
            let filters = getActiveFilter()
            events = try await repository.getEvents(filters: filters, location: userLocation)
            calculateDistances(for: events)
        } catch {
            handleError(error)
        }
    }

    func loadListings() async {
        do {
            let filters = getActiveFilter()
            listings = try await repository.getListings(filters: filters, location: userLocation)
            calculateDistances(for: listings)
        } catch {
            handleError(error)
        }
    }

    func loadInstitutions() async {
        do {
            let filters = getActiveFilter()
            institutions = try await repository.getInstitutions(filters: filters, location: userLocation)
            calculateDistances(for: institutions)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Filtering

    func applyFilter(_ filter: CommunityFilter) {
        if filter == .all {
            activeFilters = [.all]
        } else {
            activeFilters.remove(.all)
            if activeFilters.contains(filter) {
                activeFilters.remove(filter)
                if activeFilters.isEmpty {
                    activeFilters = [.all]
                }
            } else {
                activeFilters.insert(filter)
            }
        }

        updateMapPins()
    }

    private func getActiveFilter() -> CommunityFilter? {
        if activeFilters.contains(.all) {
            return nil
        }
        return activeFilters.first
    }

    // MARK: - Map Management

    private func updateMapPins() {
        var pins: [MapPin] = []

        // Add study groups
        if shouldShowType(.studyGroups) {
            for group in studyGroups {
                let pin = MapPin(
                    id: group.id,
                    type: .studyGroup(group),
                    coordinate: group.location.coordinate,
                    title: group.title,
                    subtitle: "\(group.attendeeCount)/\(group.maxAttendees) attendees",
                    distance: group.distance
                )
                pins.append(pin)
            }
        }

        // Add events
        if shouldShowType(.events) {
            for event in events {
                let pin = MapPin(
                    id: event.id,
                    type: .event(event),
                    coordinate: event.location.coordinate,
                    title: event.title,
                    subtitle: formatDate(event.dateTime),
                    distance: event.distance
                )
                pins.append(pin)
            }
        }

        // Add marketplace listings
        if shouldShowType(.marketplace) {
            for listing in listings {
                let pin = MapPin(
                    id: listing.id,
                    type: .marketplace(listing),
                    coordinate: listing.location,
                    title: listing.title,
                    subtitle: listing.priceString,
                    distance: listing.distance
                )
                pins.append(pin)
            }
        }

        // Add institutions
        if shouldShowType(.institutions) {
            for institution in institutions {
                let pin = MapPin(
                    id: institution.id,
                    type: .institution(institution),
                    coordinate: institution.location,
                    title: institution.name,
                    subtitle: institution.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    distance: institution.distance
                )
                pins.append(pin)
            }
        }

        mapPins = pins
    }

    private func shouldShowType(_ type: CommunityFilter) -> Bool {
        // If "All" is active, show everything
        if activeFilters.contains(.all) { return true }
        
        // If the specific type filter is active, show it
        if activeFilters.contains(type) { return true }
        
        // If NO specific type filters are selected (meaning only attribute filters like .nearby, .today are active),
        // then we should default to showing ALL types (filtered by attributes)
        let typeFilters: Set<CommunityFilter> = [.studyGroups, .events, .marketplace, .institutions]
        if activeFilters.isDisjoint(with: typeFilters) {
            return true
        }
        
        return false
    }

    func centerMapOnUser() {
        guard let location = userLocation else { return }
        mapRegion = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }

    func centerMapOnPin(_ pin: MapPin) {
        mapRegion = MKCoordinateRegion(
            center: pin.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        selectedPin = pin
    }

    // MARK: - Distance Calculations

    private func calculateDistances(for items: Any) {
        guard let userLocation = userLocation else { return }

        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)

        if var groups = items as? [StudyGroup] {
            for i in 0..<groups.count {
                let itemLocation = CLLocation(
                    latitude: groups[i].location.coordinate.latitude,
                    longitude: groups[i].location.coordinate.longitude
                )
                let distanceMeters = userCLLocation.distance(from: itemLocation)
                let distanceMiles = distanceMeters * 0.000621371 // Convert to miles
                groups[i].distance = distanceMiles
            }
            studyGroups = groups
        } else if var eventsList = items as? [EducationalEvent] {
            for i in 0..<eventsList.count {
                let itemLocation = CLLocation(
                    latitude: eventsList[i].location.coordinate.latitude,
                    longitude: eventsList[i].location.coordinate.longitude
                )
                let distanceMeters = userCLLocation.distance(from: itemLocation)
                let distanceMiles = distanceMeters * 0.000621371
                eventsList[i].distance = distanceMiles
            }
            events = eventsList
        } else if var listingsList = items as? [MarketplaceListing] {
            for i in 0..<listingsList.count {
                let itemLocation = CLLocation(
                    latitude: listingsList[i].location.latitude,
                    longitude: listingsList[i].location.longitude
                )
                let distanceMeters = userCLLocation.distance(from: itemLocation)
                let distanceMiles = distanceMeters * 0.000621371
                listingsList[i].distance = distanceMiles
            }
            listings = listingsList
        } else if var institutionsList = items as? [Institution] {
            for i in 0..<institutionsList.count {
                let itemLocation = CLLocation(
                    latitude: institutionsList[i].location.latitude,
                    longitude: institutionsList[i].location.longitude
                )
                let distanceMeters = userCLLocation.distance(from: itemLocation)
                let distanceMiles = distanceMeters * 0.000621371
                institutionsList[i].distance = distanceMiles
            }
            institutions = institutionsList
        }
    }

    // MARK: - Actions

    func joinStudyGroup(_ group: StudyGroup) async {
        do {
            let updated = try await repository.joinStudyGroup(groupId: group.id)
            if let index = studyGroups.firstIndex(where: { $0.id == group.id }) {
                studyGroups[index] = updated
                updateMapPins()
            }
        } catch {
            handleError(error)
        }
    }

    func registerForEvent(_ event: EducationalEvent) async {
        do {
            let updated = try await repository.registerForEvent(eventId: event.id)
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = updated
                updateMapPins()
            }
        } catch {
            handleError(error)
        }
    }

    func contactSeller(listing: MarketplaceListing) {
        // TODO: Implement chat integration
        print("Contact seller: \(listing.seller.name)")
    }

    func getDirections(to coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    func shareItem(title: String, url: String?) {
        // TODO: Implement share sheet
        print("Share: \(title)")
    }

    // MARK: - Search

    func searchInstitutions(query: String) async {
        guard !query.isEmpty else {
            await loadInstitutions()
            return
        }

        do {
            institutions = try await repository.searchInstitutions(query: query, location: userLocation)
            calculateDistances(for: institutions)
            updateMapPins()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let lyoError = error as? LyoError {
            self.error = lyoError
        } else {
            self.error = .network(.serverError(500))
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDistance(_ distance: Double?) -> String {
        guard let distance = distance else { return "" }
        return String(format: "%.1f mi", distance)
    }

    // MARK: - Computed Properties

    var availableFilters: [CommunityFilter] {
        return [.all, .studyGroups, .events, .marketplace, .institutions, .nearby(radius: 5), .today, .free]
    }

    var hasLocation: Bool {
        userLocation != nil
    }

    var filteredStudyGroups: [StudyGroup] {
        studyGroups.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
    }

    var filteredEvents: [EducationalEvent] {
        events.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
    }

    var filteredListings: [MarketplaceListing] {
        listings.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
    }

    var filteredInstitutions: [Institution] {
        institutions.sorted { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }
    }
}

// MARK: - CLLocationManagerDelegate
extension CommunityViewModel: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationPermissionStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()

            case .denied, .restricted:
                isLoadingLocation = false
                error = .network(.unauthorized)

            case .notDetermined:
                break

            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }

            userLocation = location.coordinate
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )

            isLoadingLocation = false

            // Recalculate distances for all items
            calculateDistances(for: studyGroups)
            calculateDistances(for: events)
            calculateDistances(for: listings)
            calculateDistances(for: institutions)

            // Stop updating after first successful location
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLoadingLocation = false
            self.error = LyoError.business(.invalidOperation(error.localizedDescription))
        }
    }
}
