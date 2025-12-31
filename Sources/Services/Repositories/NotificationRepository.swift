import Foundation

protocol NotificationRepository {
    func getNotifications() async throws -> [NotificationItem]
    func markAllAsRead() async
}

class DefaultNotificationRepository: NotificationRepository {
    static let shared = DefaultNotificationRepository()
    
    private init() {}
    
    func getNotifications() async throws -> [NotificationItem] {
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            // Try to fetch from backend
            let notifications: [NotificationItem] = try await NetworkClient.shared.request(Endpoints.Notifications.getNotifications(unreadOnly: false, category: nil, limit: 50, offset: 0))
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("🔔 Notifications fetched in \(String(format: "%.3f", duration))s")
            
            return notifications
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("⚠️ Failed to fetch notifications from backend: \(error). Using mock data. (Duration: \(String(format: "%.3f", duration))s)")
            
            // Fallback to mock data
            return [
                NotificationItem(title: "New Course Available", message: "Calculus II has been added to your library.", time: "2h ago", isRead: false),
                NotificationItem(title: "Streak Freeze", message: "You used a streak freeze yesterday!", time: "1d ago", isRead: true),
                NotificationItem(title: "Assignment Due", message: "Physics lab report due tomorrow.", time: "2d ago", isRead: true),
                NotificationItem(title: "Lyo Update", message: "Check out the new features in Lyo.", time: "3d ago", isRead: true),
                NotificationItem(title: "System", message: "Your profile was updated.", time: "1w ago", isRead: true)
            ]
        }
    }
    
    func markAllAsRead() async {
        do {
            _ = try await NetworkClient.shared.request(Endpoints.Notifications.markAllRead(category: nil)) as VoidResponse?
            print("✅ All notifications marked as read")
        } catch {
             print("⚠️ Failed to mark notifications as read: \(error)")
        }
    }
}

// Add VoidResponse helper if not exists, or just use `as Data?` or ignore return
// Add VoidResponse helper
struct VoidResponse: Codable {}
