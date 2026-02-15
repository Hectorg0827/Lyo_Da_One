import SwiftUI
import PhotosUI
import UIKit
import os

// MARK: - Chat View
struct ChatView: View {

    @StateObject private var viewModel = ChatViewModel()
    var recipient: APIUserPreview? = nil
    @State private var showNewConversation = false

    var body: some View {
        NavigationStack {
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
                    .refreshable {
                        await viewModel.loadConversations()
                    }
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
                            .accessibilityLabel(viewModel.isConnected ? "Connected" : "Disconnected")

                        // New conversation button
                        Button {
                            showNewConversation = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("New conversation")
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
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
                if let recipient = recipient {
                    // Convert APIUserPreview to User
                    let user = User(
                        id: recipient.id,
                        email: "",
                        name: recipient.name,
                        avatarURL: recipient.avatar,
                        createdAt: Date(),
                        level: 0, 
                        xp: 0, 
                        streak: 0, 
                        totalLessonsCompleted: 0, 
                        achievements: []
                    )
                    await viewModel.startDirectMessage(with: user)
                }
            }
            .onDisappear {
                viewModel.disconnect()
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationSheet(viewModel: viewModel)
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
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(conversation.displayName.prefix(1)))
                            .font(.title3)
                            .foregroundColor(.accentColor)
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
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

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
            return Self.shortDateFormatter.string(from: date)
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
    @State private var showAttachmentPicker = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.messageGroups.enumerated()), id: \.element.id) { index, group in
                        // Date separator
                        if index == 0 || !Calendar.current.isDate(group.timestamp, inSameDayAs: viewModel.messageGroups[index - 1].timestamp) {
                            dateSeparator(for: group.timestamp)
                        }
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
            .scrollDismissesKeyboard(.interactively)
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
                        showAttachmentPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.accentColor)
                    }
                    .accessibilityLabel("Attach file")

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
                        HapticManager.shared.light()
                        Task {
                            await viewModel.sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(viewModel.newMessageText.isEmpty ? .gray : .accentColor)
                    }
                    .disabled(viewModel.newMessageText.isEmpty)
                    .accessibilityLabel("Send message")
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
        .sheet(isPresented: $showAttachmentPicker) {
            ChatAttachmentPicker { selectedURL in
                showAttachmentPicker = false
                if let url = selectedURL {
                    Log.social.info("📎 Attachment selected: \(url.lastPathComponent)")
                }
            }
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
        VStack(alignment: group.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if !group.isFromCurrentUser {
                // Sender Info ABOVE the bubble
                HStack(spacing: 8) {
                    if let avatarURL = group.sender.avatarURL {
                        AsyncImage(url: URL(string: avatarURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(String(group.sender.name.prefix(1)))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.accentColor)
                            )
                    }
                    
                    Text(group.sender.name)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
            }

            VStack(alignment: group.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                ForEach(group.messages) { message in
                    MessageBubbleView(message: message, isFromCurrentUser: group.isFromCurrentUser)
                }

                Text(formatTime(group.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
            }
            .frame(maxWidth: group.isFromCurrentUser ? UIScreen.main.bounds.width * 0.85 : UIScreen.main.bounds.width * 0.98, alignment: group.isFromCurrentUser ? .trailing : .leading)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
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
                .background(isFromCurrentUser ? Color.accentColor : Color(.systemGray5))
                .cornerRadius(16)
                .onTapGesture {
                    handleTap()
                }

            // Read receipt for current user messages
            if isFromCurrentUser && message.readBy.count > 1 {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    Text("Read")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    private func handleTap() {
        guard !isFromCurrentUser else { return }
        
        let parsed = AICommandParser.parse(message.content)
        if case .command(let command) = parsed, command.type == .openClassroom {
            _ = AICommandHandler.shared.handleOpenClassroom(command.payload)
        }
    }
}

// MARK: - New Conversation Sheet
struct NewConversationSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search users...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Start a Conversation",
                        systemImage: "magnifyingglass",
                        description: Text("Search for a user to start chatting")
                    )
                } else {
                    ContentUnavailableView(
                        "Search Results",
                        systemImage: "person.crop.circle",
                        description: Text("User search coming in a future update")
                    )
                }

                Spacer()
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Attachment Picker (Functional)
struct ChatAttachmentPicker: View {
    let onComplete: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationStack {
            List {
                // Photo Library — real PhotosPicker
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 1,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    guard let item = items.first else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            // Write to temp file for consistent URL-based flow
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("jpg")
                            try? data.write(to: tempURL)
                            onComplete(tempURL)
                        }
                    }
                }

                // Document picker
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Document", systemImage: "doc")
                }
            }
            .navigationTitle("Attach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete(nil)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    onComplete(url)
                }
            }
        }
    }
}

// MARK: - Date Separator
extension ConversationView {
    func dateSeparator(for date: Date) -> some View {
        let text: String = {
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }()

        return HStack {
            VStack { Divider() }
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            VStack { Divider() }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - End of ChatView
// Note: TypingIndicatorView is defined in SuggestionChipsView.swift

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
}
