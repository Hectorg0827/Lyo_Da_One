import SwiftUI
import SwiftData

@available(iOS 17.0, *)
struct DrawerChatHistoryView: View {
    // SwiftData Queries
    @Query(sort: \ChatFolder.createdAt, order: .forward) private var folders: [ChatFolder]
    @Query(sort: \ChatSession.timestamp, order: .reverse) private var sessions: [ChatSession]
    
    @State private var selectedFolderId: UUID? = nil
    @State private var searchText = ""
    
    // Rename State
    @State private var isRenameAlertPresented = false
    @State private var sessionToRename: ChatSession?
    @State private var newTitle = ""
    
    // Dependencies
    private let persistence = ChatPersistenceService.shared
    
    var filteredSessions: [ChatSession] {
        var result = sessions
        
        // Filter by folder
        if let folderId = selectedFolderId {
            result = result.filter { $0.folder?.id == folderId }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.lastMessage.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Chat History")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Add Folder / New Chat Buttons
                HStack(spacing: 12) {
                    Button(action: createFolder) {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button(action: createNewChat) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search chats...", text: $searchText)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Folders Horizontal List
            if selectedFolderId == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(folders) { folder in
                            FolderCell(folder: folder) {
                                withAnimation {
                                    selectedFolderId = folder.id
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Back Button + Selected Folder Title
                HStack {
                    Button(action: {
                        withAnimation {
                            selectedFolderId = nil
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("All Chats")
                        }
                        .foregroundColor(Color(hex: "FF8C00"))
                        .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    if let folder = folders.first(where: { $0.id == selectedFolderId }) {
                        Text(folder.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Chat Sessions List
            LazyVStack(spacing: 0) {
                if filteredSessions.isEmpty {
                    Text("No chats found")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(filteredSessions) { session in
                        ChatSessionRow(session: session)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.001)) // Tappable area
                            .onTapGesture {
                                uiState.chatSessionToLoad = session
                                uiState.isLioChatPresented = true
                            }
                            // Swipe Actions
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        persistence.deleteSession(session)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation {
                                        persistence.togglePin(session)
                                    }
                                } label: {
                                    Label(session.isPinned ? "Unpin" : "Pin", systemImage: session.isPinned ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                        
                            .contextMenu {
                                Button {
                                    sessionToRename = session
                                    newTitle = session.title
                                    isRenameAlertPresented = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                            }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
        .onAppear {
            persistence.seedMockDataIfNeeded()
        }
        .alert("Rename Chat", isPresented: $isRenameAlertPresented) {
            TextField("New Title", text: $newTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let session = sessionToRename {
                    session.title = newTitle
                    // Context autosaves
                }
            }
        }
    }
    
    // Inject uiState to handle navigation
    @EnvironmentObject var uiState: AppUIState
    
    private func createFolder() {
        persistence.createFolder(name: "New Folder \(folders.count + 1)")
    }
    
    private func createNewChat() {
        persistence.createSession(title: "New Chat", message: "Starter message...", folder: nil)
    }
}

@available(iOS 17.0, *)
struct FolderCell: View {
    let folder: ChatFolder
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: folder.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: "FF8C00"))
                Text(folder.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 80)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

@available(iOS 17.0, *)
struct ChatSessionRow: View {
    let session: ChatSession
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundColor(Color(hex: "A78BFA")) // Purple accent
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Color(hex: "A78BFA").opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(session.lastMessage)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(timeAgo(session.timestamp))
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
