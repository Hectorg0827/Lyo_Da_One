import SwiftUI
import Combine
import os

// MARK: - Notification Service
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var unreadCount = 0
    @Published var isShowingNotificationCenter = false

    private let repository = LyoRepository.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Listen for notification center requests
        NotificationCenter.default.publisher(for: .showNotifications)
            .sink { [weak self] _ in
                self?.showNotificationCenter()
            }
            .store(in: &cancellables)

        // Load initial unread count
        Task {
            await loadUnreadCount()
        }
    }

    func loadUnreadCount() async {
        do {
            let notifications = try await repository.getNotifications()
            unreadCount = notifications.filter { !$0.isRead }.count
        } catch {
            Log.net.error("Failed to load notification count: \\(error.localizedDescription)")
            // Set mock count for demo
            unreadCount = 2
        }
    }

    func showNotificationCenter() {
        isShowingNotificationCenter = true
    }

    func hideNotificationCenter() {
        isShowingNotificationCenter = false
    }

    func markAllAsRead() async {
        unreadCount = 0
        do {
            try await repository.markAllNotificationsAsRead()
        } catch {
            Log.net.error("Failed to mark all notifications as read: \\(error.localizedDescription)")
        }
    }
}