import SwiftUI
import os

struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true
    
    private let repository = DefaultNotificationRepository.shared
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if notifications.isEmpty {
                    VStack {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No notifications")
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(notifications) { item in
                            HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(item.isRead ? Color.gray.opacity(0.3) : Color.blue)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(item.message)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                            
                            Text(item.time)
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await repository.markAllAsRead()
                            // Optimistically update UI
                            for i in 0..<notifications.count {
                                notifications[i].isRead = true
                            }
                        }
                    }) {
                        Text("Mark all read")
                            .font(.caption)
                    }
                }
            }
            .background(Color(hex: "0f172a"))
            .preferredColorScheme(.dark)
                }
            }
            .task {
                do {
                    isLoading = true
                    notifications = try await repository.getNotifications()
                    isLoading = false
                } catch {
                    Log.ui.error("Error loading notifications: \(error)")
                    isLoading = false
                }
            }
        }
    }
}
