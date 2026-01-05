import SwiftUI

// MARK: - Chat View
struct ChatView: View {

    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search conversations", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()

                Divider()

                // Conversations List
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if viewModel.filteredConversations.isEmpty {
                    EmptyChatView(hasSearch: !viewModel.searchQuery.isEmpty)
                } else {
                    List(viewModel.filteredConversations) { conversation in
                        NavigationLink {
                            ConversationView(conversation: conversation, viewModel: viewModel)
                        } label: {
                            ConversationRowView(conversation: conversation)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Connection indicator
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)

                        // New conversation button
                        Button {
                            // TODO: Show new conversation sheet
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
            .task {
                await viewModel.loadConversations()
            }
            .onDisappear {
                viewModel.disconnect()
            }
        }
    }
}

// MARK: - Conversation Row View
struct ConversationRowView: View {
    let conversation: ChatConversation

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = conversation.displayAvatar {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(conversation.displayName.prefix(1)))
                            .font(.title3)
                            .foregroundColor(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessage = conversation.lastMessage {
                        Text(timeAgo(from: lastMessage.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text(conversation.lastMessage?.content ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return "Now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h"
        } else if seconds < 604800 {
            let days = seconds / 86400
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Empty Chat View
struct EmptyChatView: View {
    let hasSearch: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSearch ? "magnifyingglass" : "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text(hasSearch ? "No results found" : "No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text(hasSearch ? "Try a different search" : "Start a new conversation!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Conversation View
struct ConversationView: View {
    let conversation: ChatConversation
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) var dismiss

    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messageGroups) { group in
                        MessageGroupView(group: group)
                            .id(group.id)
                    }

                    // Typing indicator
                    if !viewModel.typingUsers.isEmpty {
                        HStack {
                            TypingIndicatorView()
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onAppear {
                scrollProxy = proxy
                scrollToBottom()
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                
                // Message Input
                HStack(spacing: 12) {
                    // Attachment button
                    Button {
                        // TODO: Show attachment picker
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                    }

                    // Text input
                    TextField("Message...", text: $viewModel.newMessageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .onChange(of: viewModel.newMessageText) { _, newText in
                            if !newText.isEmpty {
                                viewModel.sendTypingIndicator(isTyping: true)
                            } else {
                                viewModel.sendTypingIndicator(isTyping: false)
                            }
                        }

                    // Send button
                    Button {
                        Task {
                            await viewModel.sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.newMessageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.newMessageText.isEmpty)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.selectConversation(conversation)
        }
    }

    private func scrollToBottom() {
        guard let lastGroup = viewModel.messageGroups.last else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollProxy?.scrollTo(lastGroup.id, anchor: .bottom)
        }
    }
}

// MARK: - Message Group View
struct MessageGroupView: View {
    let group: MessageGroup

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !group.isFromCurrentUser {
                // Avatar for other users
                if let avatarURL = group.sender.avatarURL {
                    AsyncImage(url: URL(string: avatarURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(group.sender.name.prefix(1)))
                                .font(.caption)
                                .foregroundColor(.blue)
                        )
                }
            } else {
                Spacer()
            }

            VStack(alignment: group.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !group.isFromCurrentUser {
                    Text(group.sender.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                }

                ForEach(group.messages) { message in
                    MessageBubbleView(message: message, isFromCurrentUser: group.isFromCurrentUser)
                }

                Text(formatTime(group.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }

            if group.isFromCurrentUser {
                // Empty space for current user messages
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .font(.body)
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .padding(12)
                .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                .cornerRadius(16)

            // Read receipt for current user messages
            if isFromCurrentUser && message.readBy.count > 1 {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Read")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

// MARK: - Typing Indicator View
// MARK: - End of ChatView
// Note: TypingIndicatorView is defined in SuggestionChipsView.swift

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
