import Foundation
import CoreLocation

// MARK: - Legacy Beacon Types (for compatibility)

enum BeaconType: String, Codable {
    case event
    case question
    case userActivity = "user_activity"
}

struct Beacon: Identifiable, Codable {
    // Common fields
    let type: BeaconType
    let latitude: Double
    let longitude: Double
    
    // Event specific
    let id: String? // Event ID or Question ID
    let title: String?
    let locationName: String?
    let startTime: Date?
    let endTime: Date?
    let relevanceScore: Double?
    
    // Question specific
    let text: String?
    let isResolved: Bool?
    
    // User Activity specific
    let userId: String?
    let displayName: String?
    let recentTopics: [String]?
    let level: Int?
    let xp: Int?
    
    enum CodingKeys: String, CodingKey {
        case type
        case latitude
        case longitude
        case id
        case title
        case locationName = "location_name"
        case startTime = "start_time"
        case endTime = "end_time"
        case relevanceScore = "relevance_score"
        case text
        case isResolved = "is_resolved"
        case userId = "user_id"
        case displayName = "display_name"
        case recentTopics = "recent_topics"
        case level
        case xp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(BeaconType.self, forKey: .type)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        
        // Handle heterogeneous ID types (Int for events, UUID String for questions)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decodeIfPresent(String.self, forKey: .id)
        }
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        relevanceScore = try container.decodeIfPresent(Double.self, forKey: .relevanceScore)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        isResolved = try container.decodeIfPresent(Bool.self, forKey: .isResolved)
        
        // Handle heterogeneous UserId types
        if let intUserId = try? container.decode(Int.self, forKey: .userId) {
            userId = String(intUserId)
        } else {
            userId = try container.decodeIfPresent(String.self, forKey: .userId)
        }
        
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        recentTopics = try container.decodeIfPresent([String].self, forKey: .recentTopics)
        level = try container.decodeIfPresent(Int.self, forKey: .level)
        xp = try container.decodeIfPresent(Int.self, forKey: .xp)
    }
}

struct CreateQuestionRequest: Codable {
    let text: String
    let latitude: Double
    let longitude: Double
    let locationName: String
    
    enum CodingKeys: String, CodingKey {
        case text
        case latitude
        case longitude
        case locationName = "location_name"
    }
}

struct QuestionResponse: Identifiable, Codable {
    let id: String
    let text: String
    let latitude: Double
    let longitude: Double
    let locationName: String
    let isResolved: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case latitude
        case longitude
        case locationName = "location_name"
        case isResolved = "is_resolved"
        case createdAt = "created_at"
    }
}

// MARK: - Phase 5: Campus Item Type

enum CampusItemType: String, CaseIterable, Codable {
    case event = "event"
    case workshop = "workshop"
    case meetup = "meetup"
    case studyGroup = "study_group"
    case office = "office_hours"
    
    var displayName: String {
        switch self {
        case .event: return "Event"
        case .workshop: return "Workshop"
        case .meetup: return "Meetup"
        case .studyGroup: return "Study Group"
        case .office: return "Office Hours"
        }
    }
    
    var iconName: String {
        switch self {
        case .event: return "star.fill"
        case .workshop: return "wrench.and.screwdriver.fill"
        case .meetup: return "person.3.fill"
        case .studyGroup: return "book.fill"
        case .office: return "person.crop.circle.badge.clock"
        }
    }
    
    var accentColor: String {
        switch self {
        case .event: return "purple"
        case .workshop: return "orange"
        case .meetup: return "blue"
        case .studyGroup: return "green"
        case .office: return "indigo"
        }
    }
}

// MARK: - Campus Coordinate

struct CampusCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

// MARK: - Campus Item

struct CampusItem: Identifiable, Codable {
    let id: String
    let type: CampusItemType
    let title: String
    let subtitle: String
    let locationName: String
    let coordinate: CampusCoordinate
    let startTime: Date
    let endTime: Date
    let roomId: String?
    let hostName: String
    let hostAvatarURL: String?
    let attendeeCount: Int
    let maxAttendees: Int?
    let tags: [String]
    
    var isLive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var isFull: Bool {
        guard let maxAtt = maxAttendees else { return false }
        return attendeeCount >= maxAtt
    }
    
    var spotsRemaining: Int? {
        guard let maxAtt = maxAttendees else { return nil }
        return Swift.max(0, maxAtt - attendeeCount)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: startTime)
    }
    
    // For mock data
    static func mockItems() -> [CampusItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            CampusItem(
                id: "campus-1",
                type: CampusItemType.workshop,
                title: "SwiftUI Animations Deep Dive",
                subtitle: "Master advanced animation techniques",
                locationName: "Innovation Lab",
                coordinate: CampusCoordinate(latitude: 37.7749, longitude: -122.4194),
                startTime: calendar.date(byAdding: Calendar.Component.hour, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: Calendar.Component.hour, value: 3, to: now) ?? now,
                roomId: "collab-swift-animations",
                hostName: "Sarah Chen",
                hostAvatarURL: nil as String?,
                attendeeCount: 12,
                maxAttendees: 20,
                tags: ["SwiftUI", "iOS", "Animation"]
            ),
            CampusItem(
                id: "campus-2",
                type: CampusItemType.studyGroup,
                title: "Algorithms Study Session",
                subtitle: "Preparing for technical interviews",
                locationName: "Library Room 3B",
                coordinate: CampusCoordinate(latitude: 37.7751, longitude: -122.4180),
                startTime: calendar.date(byAdding: Calendar.Component.hour, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: Calendar.Component.hour, value: 4, to: now) ?? now,
                roomId: "collab-algo-study",
                hostName: "Mike Johnson",
                hostAvatarURL: nil as String?,
                attendeeCount: 5,
                maxAttendees: 8,
                tags: ["Algorithms", "Interview", "LeetCode"]
            ),
            CampusItem(
                id: "campus-3",
                type: CampusItemType.meetup,
                title: "iOS Developers Hangout",
                subtitle: "Weekly informal meetup",
                locationName: "Campus Cafe",
                coordinate: CampusCoordinate(latitude: 37.7745, longitude: -122.4200),
                startTime: calendar.date(byAdding: Calendar.Component.day, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: Calendar.Component.hour, value: 26, to: now) ?? now,
                roomId: "collab-ios-hangout",
                hostName: "iOS Community",
                hostAvatarURL: nil as String?,
                attendeeCount: 18,
                maxAttendees: nil as Int?,
                tags: ["iOS", "Networking", "Community"]
            ),
            CampusItem(
                id: "campus-4",
                type: CampusItemType.office,
                title: "Career Advice Office Hours",
                subtitle: "1-on-1 mentorship sessions",
                locationName: "Career Center",
                coordinate: CampusCoordinate(latitude: 37.7755, longitude: -122.4188),
                startTime: calendar.date(byAdding: Calendar.Component.hour, value: 3, to: now) ?? now,
                endTime: calendar.date(byAdding: Calendar.Component.hour, value: 5, to: now) ?? now,
                roomId: nil as String?,
                hostName: "Dr. Emily Wong",
                hostAvatarURL: nil as String?,
                attendeeCount: 2,
                maxAttendees: 6,
                tags: ["Career", "Mentorship"]
            ),
            CampusItem(
                id: "campus-5",
                type: CampusItemType.event,
                title: "Tech Talk: Building at Scale",
                subtitle: "Learn from industry experts",
                locationName: "Main Auditorium",
                coordinate: CampusCoordinate(latitude: 37.7760, longitude: -122.4195),
                startTime: calendar.date(byAdding: Calendar.Component.day, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: Calendar.Component.hour, value: 50, to: now) ?? now,
                roomId: "collab-tech-talk",
                hostName: "Tech Talks Team",
                hostAvatarURL: nil as String?,
                attendeeCount: 85,
                maxAttendees: 200,
                tags: ["Tech Talk", "Engineering", "Scale"]
            )
        ]
    }
}

// MARK: - Community Models Consolidation
// Imported from ContentModels.swift due to build system issues

enum LibraryContentType: String, Codable, CaseIterable, Hashable {
    case anchorCourse = "anchor_course"
    case miniCourse = "mini_course"
    case microLesson = "micro_lesson"
    case learningPath = "learning_path"
    
    var displayName: String {
        switch self {
        case .anchorCourse: return "Course"
        case .miniCourse: return "Mini-Course"
        case .microLesson: return "Micro-Lesson"
        case .learningPath: return "Path"
        }
    }
    
    var icon: String {
        switch self {
        case .anchorCourse: return "book.closed.fill"
        case .miniCourse: return "laptopcomputer"
        case .microLesson: return "bolt.fill"
        case .learningPath: return "map.fill"
        }
    }
}

struct ContentItem: Identifiable, Codable, Hashable {
    let id: String
    let type: LibraryContentType
    let title: String
    let description: String
    let coverImage: String // Asset name or URL
    let duration: TimeInterval // in seconds
    let author: ContentAuthor
    let tags: [String]
    let level: ContentLevel
    var stats: ContentStats
    var progress: Double = 0.0 // 0.0 to 1.0
    
    // For Paths: ordered list of child content IDs
    var childContentIds: [String]?
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            return "\(hours)h \(minutes % 60)m"
        }
    }
    
    var isTrending: Bool {
        stats.views > 1000
    }
    
    // Manual Hashable conformance to resolve build issues
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
        hasher.combine(title)
        hasher.combine(description)
        hasher.combine(coverImage)
        hasher.combine(duration)
        hasher.combine(author)
        hasher.combine(tags)
        hasher.combine(level)
        hasher.combine(stats)
        hasher.combine(progress)
        hasher.combine(childContentIds)
    }
    
    static func == (lhs: ContentItem, rhs: ContentItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description &&
               lhs.coverImage == rhs.coverImage &&
               lhs.duration == rhs.duration &&
               lhs.author == rhs.author &&
               lhs.tags == rhs.tags &&
               lhs.level == rhs.level &&
               lhs.stats == rhs.stats &&
               lhs.progress == rhs.progress &&
               lhs.childContentIds == rhs.childContentIds
    }
}

struct ContentAuthor: Codable, Hashable {
    let name: String
    let avatar: String // Asset name
    let role: String // e.g., "Industry Expert"
}

enum ContentLevel: String, Codable, Hashable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case allLevels = "All Levels"
}

struct ContentStats: Codable, Hashable {
    var views: Int
    var likes: Int
    var rating: Double
}

enum CampusViewMode: String, Codable, CaseIterable {
    case library = "Library"
    case map = "Map"
    case list = "List"
    case feed = "Feed"
    
    var iconName: String {
        switch self {
        case .library: return "books.vertical.fill"
        case .map: return "map.fill"
        case .list: return "list.bullet"
        case .feed: return "square.text.square.fill"
        }
    }
}

