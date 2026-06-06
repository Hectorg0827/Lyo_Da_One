import Foundation
import CoreLocation

// MARK: - Default Community Repository
class DefaultCommunityRepository: CommunityRepository {

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    init() {}

    // MARK: - Study Groups

    func getStudyGroups(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [StudyGroup] {
        struct Response: Codable {
            let studyGroups: [StudyGroup]

            enum CodingKeys: String, CodingKey {
                case studyGroups = "study_groups"
            }
        }

        let response: Response = try await networkClient.request(
            Endpoints.Community.getStudyGroups(filters: filters, location: location),
            cachePolicy: .default
        )

        logger.log("✅ Study groups fetched: \(response.studyGroups.count)")
        return response.studyGroups
    }

    func getStudyGroup(id: String) async throws -> StudyGroup {
        let group: StudyGroup = try await networkClient.request(
            Endpoints.Community.getStudyGroup(id: id),
            cachePolicy: .default
        )

        logger.log("✅ Study group fetched: \(group.title)")
        return group
    }

    func createStudyGroup(group: StudyGroup) async throws -> StudyGroup {
        let created: StudyGroup = try await networkClient.request(
            Endpoints.Community.createStudyGroup(group: group),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Study group created: \(created.title)")
        return created
    }

    func joinStudyGroup(groupId: String) async throws -> StudyGroup {
        let group: StudyGroup = try await networkClient.request(
            Endpoints.Community.joinStudyGroup(groupId: groupId),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Joined study group: \(group.title)")
        return group
    }

    func leaveStudyGroup(groupId: String) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await networkClient.request(
            Endpoints.Community.leaveStudyGroup(groupId: groupId),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Left study group: \(groupId)")
    }

    // MARK: - Events

    func getEvents(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [EducationalEvent] {
        struct Response: Codable {
            let events: [EducationalEvent]
        }

        let response: Response = try await networkClient.request(
            Endpoints.Community.getEvents(filters: filters, location: location),
            cachePolicy: .default
        )

        logger.log("✅ Events fetched: \(response.events.count)")
        return response.events
    }

    func getEvent(id: String) async throws -> EducationalEvent {
        let event: EducationalEvent = try await networkClient.request(
            Endpoints.Community.getEvent(id: id),
            cachePolicy: .default
        )

        logger.log("✅ Event fetched: \(event.title)")
        return event
    }

    func createEvent(event: EducationalEvent) async throws -> EducationalEvent {
        let created: EducationalEvent = try await networkClient.request(
            Endpoints.Community.createEvent(event: event),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Event created: \(created.title)")
        return created
    }

    func registerForEvent(eventId: String) async throws -> EducationalEvent {
        let event: EducationalEvent = try await networkClient.request(
            Endpoints.Community.registerForEvent(eventId: eventId),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Registered for event: \(event.title)")
        return event
    }

    func unregisterFromEvent(eventId: String) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await networkClient.request(
            Endpoints.Community.unregisterFromEvent(eventId: eventId),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Unregistered from event: \(eventId)")
    }

    // MARK: - Marketplace

    func getListings(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [MarketplaceListing] {
        struct Response: Codable {
            let listings: [MarketplaceListing]
        }

        let response: Response = try await networkClient.request(
            Endpoints.Community.getListings(filters: filters, location: location),
            cachePolicy: .default
        )

        logger.log("✅ Marketplace listings fetched: \(response.listings.count)")
        return response.listings
    }

    func getListing(id: String) async throws -> MarketplaceListing {
        let listing: MarketplaceListing = try await networkClient.request(
            Endpoints.Community.getListing(id: id),
            cachePolicy: .default
        )

        logger.log("✅ Listing fetched: \(listing.title)")
        return listing
    }

    func createListing(listing: MarketplaceListing) async throws -> MarketplaceListing {
        let request = APIMarketplaceListingRequest(
            title: listing.title,
            description: listing.description,
            price: listing.listingType.priceValue ?? 0,
            currency: listing.currencyCode ?? "USD",
            category: listing.category.rawValue,
            condition: listing.condition.rawValue,
            lat: listing.location.latitude,
            lng: listing.location.longitude,
            images: listing.photos
        )
        let created: MarketplaceListing = try await networkClient.request(
            Endpoints.Community.createListing(listing: request),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Listing created: \(created.title)")
        return created
    }

    func updateListing(listingId: String, status: MarketplaceListing.ListingStatus) async throws -> MarketplaceListing {
        let updated: MarketplaceListing = try await networkClient.request(
            Endpoints.Community.updateListing(listingId: listingId, status: status),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Listing updated: \(updated.title)")
        return updated
    }

    func deleteListing(listingId: String) async throws {
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await networkClient.request(
            Endpoints.Community.deleteListing(listingId: listingId),
            cachePolicy: .reloadIgnoringCache
        )

        logger.log("✅ Listing deleted: \(listingId)")
    }

    // MARK: - Institutions

    func getInstitutions(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [Institution] {
        struct Response: Codable {
            let institutions: [Institution]
        }

        let response: Response = try await networkClient.request(
            Endpoints.Community.getInstitutions(filters: filters, location: location),
            cachePolicy: .default
        )

        logger.log("✅ Institutions fetched: \(response.institutions.count)")
        return response.institutions
    }

    func getInstitution(id: String) async throws -> Institution {
        let institution: Institution = try await networkClient.request(
            Endpoints.Community.getInstitution(id: id),
            cachePolicy: .default
        )

        logger.log("✅ Institution fetched: \(institution.name)")
        return institution
    }

    func searchInstitutions(query: String, location: CLLocationCoordinate2D?) async throws -> [Institution] {
        struct Response: Codable {
            let institutions: [Institution]
        }

        let response: Response = try await networkClient.request(
            Endpoints.Community.searchInstitutions(query: query, location: location),
            cachePolicy: .default
        )

        logger.log("✅ Institution search results: \(response.institutions.count)")
        return response.institutions
    }
}

// MARK: - Mock Community Repository
class MockCommunityRepository: CommunityRepository {

    private var studyGroups: [StudyGroup] = []
    private var events: [EducationalEvent] = []
    private var listings: [MarketplaceListing] = []
    private var institutions: [Institution] = []

    init() {
        generateMockData()
    }

    private func generateMockData() {
        let mockUser = User(id: 1001, email: "john@lyo.app", name: "John Doe", avatarURL: nil, createdAt: Date(), level: 5, xp: 2500, streak: 3, totalLessonsCompleted: 10, achievements: [])
        let mockCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco

        // Mock Study Groups
        studyGroups = [
            StudyGroup(
                id: "sg1",
                title: "Python Study Group",
                description: "Learn Python together every week",
                organizer: mockUser,
                location: Location(type: .institution, name: "SF Library", coordinate: mockCoordinate, address: "100 Larkin St"),
                schedule: .recurring(dayOfWeek: 3, hour: 18, minute: 0, duration: 7200),
                maxAttendees: 10,
                currentAttendees: [mockUser],
                skillLevel: .intermediate,
                relatedCourse: "Python Basics",
                cost: 0,
                tags: ["python", "coding", "beginner-friendly"],
                createdAt: Date(),
                isVerified: true
            )
        ]

        // Mock Events
        events = [
            EducationalEvent(
                id: "ev1",
                title: "Web Development Workshop",
                description: "Build your first website",
                organizer: mockUser,
                location: Location(type: .institution, name: "SF Library", coordinate: mockCoordinate),
                dateTime: Date().addingTimeInterval(86400),
                duration: 10800,
                capacity: 30,
                registeredUsers: [mockUser],
                cost: 0,
                skillLevel: .beginner,
                category: .workshop,
                tags: ["web", "html", "css"],
                coverImageURL: nil,
                isVerified: true
            )
        ]

        // Mock Listings
        listings = [
            MarketplaceListing(
                id: "ml1",
                seller: mockUser,
                title: "Calculus Textbook",
                description: "Stewart Calculus 8th Edition, like new",
                category: .textbook,
                condition: .likeNew,
                photos: [],
                listingType: .sell(price: 45.00),
                location: mockCoordinate,
                tags: ["math", "calculus", "textbook"],
                createdAt: Date(),
                currencyCode: "USD",
                status: .active
            )
        ]

        // Mock Institutions
        institutions = [
            Institution(
                id: "inst1",
                name: "San Francisco Public Library",
                type: .library,
                location: mockCoordinate,
                address: "100 Larkin St, San Francisco, CA 94102",
                phone: "(415) 557-4400",
                website: "https://sfpl.org",
                hours: ["Monday": "9:00 AM - 6:00 PM", "Tuesday": "9:00 AM - 6:00 PM"],
                amenities: [.freeWiFi, .quietStudyRooms, .groupStudyRooms],
                isVerified: true,
                isLyoPartner: true,
                photos: [],
                rating: 4.5
            )
        ]
    }

    // MARK: - Study Groups

    func getStudyGroups(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [StudyGroup] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return studyGroups
    }

    func getStudyGroup(id: String) async throws -> StudyGroup {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let group = studyGroups.first(where: { $0.id == id }) else {
            throw LyoError.network(.notFound)
        }
        return group
    }

    func createStudyGroup(group: StudyGroup) async throws -> StudyGroup {
        try await Task.sleep(nanoseconds: 400_000_000)
        studyGroups.append(group)
        return group
    }

    func joinStudyGroup(groupId: String) async throws -> StudyGroup {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let group = studyGroups.first(where: { $0.id == groupId }) else {
            throw LyoError.network(.notFound)
        }
        return group
    }

    func leaveStudyGroup(groupId: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    // MARK: - Events

    func getEvents(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [EducationalEvent] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return events
    }

    func getEvent(id: String) async throws -> EducationalEvent {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let event = events.first(where: { $0.id == id }) else {
            throw LyoError.network(.notFound)
        }
        return event
    }

    func createEvent(event: EducationalEvent) async throws -> EducationalEvent {
        try await Task.sleep(nanoseconds: 400_000_000)
        events.append(event)
        return event
    }

    func registerForEvent(eventId: String) async throws -> EducationalEvent {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let event = events.first(where: { $0.id == eventId }) else {
            throw LyoError.network(.notFound)
        }
        return event
    }

    func unregisterFromEvent(eventId: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    // MARK: - Marketplace

    func getListings(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [MarketplaceListing] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return listings
    }

    func getListing(id: String) async throws -> MarketplaceListing {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let listing = listings.first(where: { $0.id == id }) else {
            throw LyoError.network(.notFound)
        }
        return listing
    }

    func createListing(listing: MarketplaceListing) async throws -> MarketplaceListing {
        try await Task.sleep(nanoseconds: 400_000_000)
        listings.append(listing)
        return listing
    }

    func updateListing(listingId: String, status: MarketplaceListing.ListingStatus) async throws -> MarketplaceListing {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let listing = listings.first(where: { $0.id == listingId }) else {
            throw LyoError.network(.notFound)
        }
        return listing
    }

    func deleteListing(listingId: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        listings.removeAll { $0.id == listingId }
    }

    // MARK: - Institutions

    func getInstitutions(filters: CommunityFilter?, location: CLLocationCoordinate2D?) async throws -> [Institution] {
        try await Task.sleep(nanoseconds: 500_000_000)
        return institutions
    }

    func getInstitution(id: String) async throws -> Institution {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard let institution = institutions.first(where: { $0.id == id }) else {
            throw LyoError.network(.notFound)
        }
        return institution
    }

    func searchInstitutions(query: String, location: CLLocationCoordinate2D?) async throws -> [Institution] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return institutions.filter { $0.name.lowercased().contains(query.lowercased()) }
    }
}
