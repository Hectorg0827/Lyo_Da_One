import SwiftUI

struct NotificationCenterView: View {
    @StateObject private var viewModel = NotificationCenterViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading notifications...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.notifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.notifications) { notification in
                                NotificationRowView(notification: notification) {
                                    Task {
                                        await viewModel.markAsRead(notification.id)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !viewModel.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark All Read") {
                            Task {
                                await viewModel.markAllAsRead()
                            }
                        }
                        .disabled(viewModel.unreadCount == 0)
                    }
                }
            }
            .task {
                await viewModel.loadNotifications()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showNotifications)) { _ in
                // Already showing, just refresh
                Task {
                    await viewModel.loadNotifications()
                }
            }
        }
    }
}

struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("You're all caught up! New notifications will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NotificationRowView: View {
    let notification: APIAppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundColor(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(notification.isRead ? .medium : .semibold)
                        .foregroundColor(.primary)

                    Text(notification.body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(notification.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(notification.isRead ? Color(.secondarySystemBackground) : Color.blue.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconName: String {
        switch notification.category.lowercased() {
        case "achievement":
            return "trophy.fill"
        case "course":
            return "book.fill"
        case "social":
            return "person.2.fill"
        case "system":
            return "gear"
        case "reminder":
            return "clock.fill"
        default:
            return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.category.lowercased() {
        case "achievement":
            return .yellow
        case "course":
            return .blue
        case "social":
            return .green
        case "system":
            return .gray
        case "reminder":
            return .orange
        default:
            return .blue
        }
    }
}

@MainActor
class NotificationCenterViewModel: ObservableObject {
    @Published var notifications: [APIAppNotification] = []
    @Published var isLoading = false

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private let repository = LyoRepository.shared

    func loadNotifications() async {
        isLoading = true

        do {
            notifications = try await repository.getNotifications()
            print("✅ Loaded \\(notifications.count) notifications")
        } catch {
            print("❌ Failed to load notifications: \\(error.localizedDescription)")
            // Create some mock notifications for demo
            notifications = createMockNotifications()
        }

        isLoading = false
    }

    func markAsRead(_ notificationId: Int) async {
        // Optimistically update UI
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            var updated = notifications[index]
            updated.isRead = true
            notifications[index] = updated
        }

        do {
            try await repository.markNotificationAsRead(notificationId)
        } catch {
            print("❌ Failed to mark notification as read: \\(error.localizedDescription)")
        }
    }

    func markAllAsRead() async {
        // Optimistically update UI
        for index in notifications.indices {
            notifications[index].isRead = true
        }

        do {
            try await repository.markAllNotificationsAsRead()
        } catch {
            print("❌ Failed to mark all notifications as read: \\(error.localizedDescription)")
        }
    }

    private func createMockNotifications() -> [APIAppNotification] {
        return [
            APIAppNotification(
                id: 1,
                title: "Achievement Unlocked!",
                body: "You've earned the 'Week Warrior' achievement for completing 7 days in a row!",
                icon: "trophy.fill",
                imageUrl: nil,
                category: "achievement",
                priority: "high",
                actionType: nil,
                actionData: nil,
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600),
                readAt: nil
            ),
            APIAppNotification(
                id: 2,
                title: "New Course Available",
                body: "Advanced Python Programming is now available in your library.",
                icon: "book.fill",
                imageUrl: nil,
                category: "course",
                priority: "medium",
                actionType: nil,
                actionData: nil,
                isRead: false,
                createdAt: Date().addingTimeInterval(-7200),
                readAt: nil
            ),
            APIAppNotification(
                id: 3,
                title: "Study Group Invitation",
                body: "Alice invited you to join the 'Math Masters' study group.",
                icon: "person.2.fill",
                imageUrl: nil,
                category: "social",
                priority: "medium",
                actionType: nil,
                actionData: nil,
                isRead: true,
                createdAt: Date().addingTimeInterval(-14400),
                readAt: Date().addingTimeInterval(-14000)
            )
        ]
    }
}

struct NotificationCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationCenterView()
    }
}