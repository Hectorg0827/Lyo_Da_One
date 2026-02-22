import Foundation

// MARK: - App Notification Model
struct AppNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    var isRead: Bool
    let createdAt: Date
    let data: [String: String]? // Additional data for notification actions

    enum NotificationType: String, Codable, CaseIterable {
        case achievement = "achievement"
        case course = "course"
        case social = "social"
        case system = "system"
        case reminder = "reminder"

        var displayName: String {
            switch self {
            case .achievement:
                return "Achievement"
            case .course:
                return "Course"
            case .social:
                return "Social"
            case .system:
                return "System"
            case .reminder:
                return "Reminder"
            }
        }
    }

    init(id: String, type: NotificationType, title: String, message: String, isRead: Bool = false, createdAt: Date = Date(), data: [String: String]? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.isRead = isRead
        self.createdAt = createdAt
        self.data = data
    }
}