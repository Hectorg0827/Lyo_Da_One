import Foundation
import MapKit

// MARK: - Community Models
/// Models for Community Hub features (study groups, events, marketplace, institutions)

// MARK: - Study Group
struct StudyGroup: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let organizer: User
    let location: Location
    let schedule: Schedule
    let maxAttendees: Int
    var currentAttendees: [User]
    let skillLevel: SkillLevel
    let relatedCourse: String?
    let cost: Double
    let tags: [String]
    let createdAt: Date
    let isVerified: Bool

    var attendeeCount: Int {
        currentAttendees.count
    }

    var isFull: Bool {
        maxAttendees > 0 && attendeeCount >= maxAttendees
    }

    var distance: Double? // Set by location service

    enum CodingKeys: String, CodingKey {
        case id, title, description, organizer, location, schedule, maxAttendees, currentAttendees, skillLevel, relatedCourse, cost, tags, createdAt, isVerified
    }
}

// MARK: - Educational Event
struct EducationalEvent: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let organizer: User
    let location: Location
    let dateTime: Date
    let duration: TimeInterval
    let capacity: Int
    var registeredUsers: [User]
    let cost: Double
    let skillLevel: SkillLevel
    let category: EventCategory
    let tags: [String]
    let coverImageURL: String?
    let isVerified: Bool

    enum EventCategory: String, Codable {
        case workshop
        case tutoring
        case competition
        case lecture
        case officeHours = "office_hours"
    }

    var registrationCount: Int {
        registeredUsers.count
    }

    var isFull: Bool {
        capacity > 0 && registrationCount >= capacity
    }

    var distance: Double? // Set by location service

    enum CodingKeys: String, CodingKey {
        case id, title, description, organizer, location, dateTime, duration, capacity, registeredUsers, cost, skillLevel, category, tags, coverImageURL, isVerified
    }
}

// MARK: - Marketplace Listing
struct MarketplaceListing: Identifiable, Codable {
    let id: String
    let seller: User
    let title: String
    let description: String
    let category: ItemCategory
    let condition: ItemCondition
    let photos: [String]
    let listingType: ListingType
    let location: CLLocationCoordinate2D
    let tags: [String]
    let createdAt: Date
    let currencyCode: String?
    let status: ListingStatus

    enum ItemCategory: String, Codable {
        case textbook
        case studyGuide = "study_guide"
        case flashcards
        case equipment
        case digitalAccess = "digital_access"
        case other
    }

    enum ItemCondition: String, Codable {
        case new
        case likeNew = "like_new"
        case good
        case acceptable
        case poor
    }

    enum ListingType: Codable {
        case sell(price: Double)
        case trade(lookingFor: String)
        case free

        enum CodingKeys: String, CodingKey {
            case type
            case price
            case lookingFor = "looking_for"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "sell":
                let price = try container.decode(Double.self, forKey: .price)
                self = .sell(price: price)
            case "trade":
                let lookingFor = try container.decode(String.self, forKey: .lookingFor)
                self = .trade(lookingFor: lookingFor)
            case "free":
                self = .free
            default:
                self = .free
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .sell(let price):
                try container.encode("sell", forKey: .type)
                try container.encode(price, forKey: .price)
            case .trade(let lookingFor):
                try container.encode("trade", forKey: .type)
                try container.encode(lookingFor, forKey: .lookingFor)
            case .free:
                try container.encode("free", forKey: .type)
            }
        }

        var priceValue: Double? {
            if case .sell(let price) = self {
                return price
            }
            return nil
        }
    }

    enum ListingStatus: String, Codable {
        case active
        case pending
        case sold
        case expired
    }

    var distance: Double? // Set by location service
    var priceString: String {
        switch listingType {
        case .sell(let price):
            return "$\(String(format: "%.2f", price))"
        case .trade(let lookingFor):
            return "Trade for: \(lookingFor)"
        case .free:
            return "Free"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, seller, title, description, category, condition, photos, listingType, location, tags, createdAt, status
        case currencyCode = "currency_code"
    }
}

// MARK: - Institution
struct Institution: Identifiable, Codable {
    let id: String
    let name: String
    let type: InstitutionType
    let location: CLLocationCoordinate2D
    let address: String
    let phone: String?
    let website: String?
    let hours: [String: String]? // DayOfWeek: TimeRange
    let amenities: [Amenity]
    let isVerified: Bool
    let isLyoPartner: Bool
    let photos: [String]
    let rating: Double?

    enum InstitutionType: String, Codable {
        case library
        case school
        case cafe
        case communityCenter = "community_center"
        case bookstore
        case coworkingSpace = "coworking_space"
    }

    enum Amenity: String, Codable {
        case freeWiFi = "free_wifi"
        case quietStudyRooms = "quiet_study_rooms"
        case groupStudyRooms = "group_study_rooms"
        case whiteboards
        case printing
        case foodDrinks = "food_drinks"
        case outdoorSeating = "outdoor_seating"
    }

    var distance: Double? // Set by location service
}

// MARK: - Location
struct Location: Codable {
    let type: LocationType
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String?

    enum LocationType: String, Codable {
        case institution
        case coordinates
        case virtual
    }

    init(type: LocationType, name: String, coordinate: CLLocationCoordinate2D, address: String? = nil) {
        self.type = type
        self.name = name
        self.coordinate = coordinate
        self.address = address
    }

    // Custom Codable implementation for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case type
        case name
        case latitude
        case longitude
        case address
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(LocationType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        address = try container.decodeIfPresent(String.self, forKey: .address)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(address, forKey: .address)
    }
}

// MARK: - Schedule
enum Schedule: Codable {
    case oneTime(date: Date, duration: TimeInterval)
    case recurring(dayOfWeek: Int, hour: Int, minute: Int, duration: TimeInterval)

    enum CodingKeys: String, CodingKey {
        case type
        case date
        case duration
        case dayOfWeek = "day_of_week"
        case hour
        case minute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "one_time":
            let date = try container.decode(Date.self, forKey: .date)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .oneTime(date: date, duration: duration)

        case "recurring":
            let dayOfWeek = try container.decode(Int.self, forKey: .dayOfWeek)
            let hour = try container.decode(Int.self, forKey: .hour)
            let minute = try container.decode(Int.self, forKey: .minute)
            let duration = try container.decode(TimeInterval.self, forKey: .duration)
            self = .recurring(dayOfWeek: dayOfWeek, hour: hour, minute: minute, duration: duration)

        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown schedule type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .oneTime(let date, let duration):
            try container.encode("one_time", forKey: .type)
            try container.encode(date, forKey: .date)
            try container.encode(duration, forKey: .duration)

        case .recurring(let dayOfWeek, let hour, let minute, let duration):
            try container.encode("recurring", forKey: .type)
            try container.encode(dayOfWeek, forKey: .dayOfWeek)
            try container.encode(hour, forKey: .hour)
            try container.encode(minute, forKey: .minute)
            try container.encode(duration, forKey: .duration)
        }
    }

    var displayString: String {
        switch self {
        case .oneTime(let date, let duration):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "\(formatter.string(from: date)) (\(Int(duration / 60)) min)"

        case .recurring(let dayOfWeek, let hour, let minute, let duration):
            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let dayName = days[dayOfWeek % 7]
            return "\(dayName)s at \(hour):\(String(format: "%02d", minute)) (\(Int(duration / 60)) min)"
        }
    }
}

// MARK: - Map Pin
struct MapPin: Identifiable {
    let id: String
    let type: MapPinType
    let coordinate: CLLocationCoordinate2D
    let title: String
    let subtitle: String
    var distance: Double? // in miles

    enum MapPinType {
        case studyGroup(StudyGroup)
        case event(EducationalEvent)
        case marketplace(MarketplaceListing)
        case institution(Institution)

        var icon: String {
            switch self {
            case .studyGroup: return "person.3.fill"
            case .event: return "calendar.badge.clock"
            case .marketplace: return "bag.fill"
            case .institution: return "building.2.fill"
            }
        }

        var color: String {
            switch self {
            case .studyGroup: return "purple"
            case .event: return "blue"
            case .marketplace: return "green"
            case .institution: return "gray"
            }
        }
    }
}

// MARK: - Community Filter
enum CommunityFilter: Identifiable, Equatable, Hashable {
    case all
    case studyGroups
    case events
    case marketplace
    case institutions
    case nearby(radius: Double) // miles
    case today
    case free

    var id: String {
        switch self {
        case .all: return "all"
        case .studyGroups: return "study_groups"
        case .events: return "events"
        case .marketplace: return "marketplace"
        case .institutions: return "institutions"
        case .nearby(let radius): return "nearby_\(radius)"
        case .today: return "today"
        case .free: return "free"
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .studyGroups: return "Study Groups"
        case .events: return "Events"
        case .marketplace: return "Marketplace"
        case .institutions: return "Institutions"
        case .nearby(let radius): return "Within \(Int(radius))mi"
        case .today: return "Today"
        case .free: return "Free"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .studyGroups: return "person.3"
        case .events: return "calendar"
        case .marketplace: return "bag"
        case .institutions: return "building.2"
        case .nearby: return "location"
        case .today: return "clock"
        case .free: return "dollarsign.circle"
        }
    }
}

// MARK: - Community Stats

struct CommunityStats: Codable {
    let totalStudyGroups: Int
    let totalEvents: Int
    let totalMembers: Int
    let groupsJoined: Int
    let eventsAttended: Int
    let questionsAsked: Int
    let questionsAnswered: Int
    
    enum CodingKeys: String, CodingKey {
        case totalStudyGroups = "total_study_groups"
        case totalEvents = "total_events"
        case totalMembers = "total_members"
        case groupsJoined = "groups_joined"
        case eventsAttended = "events_attended"
        case questionsAsked = "questions_asked"
        case questionsAnswered = "questions_answered"
    }
}

// MARK: - CLLocationCoordinate2D Extension
extension CLLocationCoordinate2D: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let latitude = try container.decode(Double.self)
        let longitude = try container.decode(Double.self)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(latitude)
        try container.encode(longitude)
    }
}
