import Foundation

struct NotificationItem: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    let title: String
    let message: String
    let time: String
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case message
        case time
        case isRead = "is_read"
    }
}
