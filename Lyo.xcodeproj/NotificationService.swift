import SwiftUI
import Foundation

final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var unreadCount: Int = 0
    @Published var isShowingNotificationCenter: Bool = false
    
    private init() {}
    
    struct UnreadCountResponse: Codable {
        let count: Int
    }
    
    func loadUnreadCount() async {
        do {
            let response = try await NetworkClient.shared.request(Endpoints.Notifications.getUnreadCount)
            // Try to decode as Int directly
            if let intCount = try? JSONDecoder().decode(Int.self, from: response) {
                await MainActor.run {
                    self.unreadCount = intCount
                }
                return
            }
            // Try to decode as UnreadCountResponse
            let decoded = try JSONDecoder().decode(UnreadCountResponse.self, from: response)
            await MainActor.run {
                self.unreadCount = decoded.count
            }
        } catch {
            // Do nothing, keep unreadCount unchanged
        }
    }
    
    func showNotificationCenter() {
        isShowingNotificationCenter = true
    }
}

struct NotificationCenterView: View {
    @ObservedObject private var notificationService = NotificationService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Notification Center")
                .font(.title)
            
            Button("Dismiss") {
                notificationService.isShowingNotificationCenter = false
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
    }
}
