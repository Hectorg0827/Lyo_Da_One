import Foundation
import os

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
            Log.net.info("🔔 Notifications fetched in \(String(format: "%.3f", duration))s")
            
            return notifications
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Log.net.warning("Failed to fetch notifications from backend: \(error). (Duration: \(String(format: "%.3f", duration))s)")
            // The screen shows its own empty/error state; no invented notifications.
            throw error
        }
    }
    
    func markAllAsRead() async {
        do {
            _ = try await NetworkClient.shared.request(Endpoints.Notifications.markAllRead(category: nil)) as VoidResponse?
            Log.net.info("All notifications marked as read")
        } catch {
             Log.net.warning("Failed to mark notifications as read: \(error)")
        }
    }
}

// Add VoidResponse helper if not exists, or just use `as Data?` or ignore return
// Add VoidResponse helper
struct VoidResponse: Codable {}
