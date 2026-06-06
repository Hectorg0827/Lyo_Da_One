//
//  ChatHistoryView.swift
//  Lyo
//
//  View for managing and selecting chat conversations
//

import SwiftUI

struct ChatHistoryView: View {
    @ObservedObject var conversationManager = ConversationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: SavedConversation?
    @State private var editingConversation: SavedConversation?
    @State private var newTitle = ""
    
    var onSelectConversation: (SavedConversation) -> Void
    var onNewChat: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                if conversationManager.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        createNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .alert("Delete Conversation", isPresented: $showingDeleteAlert, presenting: conversationToDelete) { conversation in
                Button("Delete", role: .destructive) {
                    conversationManager.deleteConversation(conversation)
                }
                Button("Cancel", role: .cancel) {}
            } message: { conversation in
                Text("Are you sure you want to delete \"\(conversation.title)\"? This action cannot be undone.")
            }
            .alert("Rename Conversation", isPresented: .constant(editingConversation != nil), presenting: editingConversation) { conversation in
                TextField("New Title", text: $newTitle)
                Button("Save") {
                    conversationManager.renameConversation(conversation, newTitle: newTitle)
                    editingConversation = nil
                }
                Button("Cancel", role: .cancel) {
                    editingConversation = nil
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Conversations Yet")
                .font(.title2.bold())
            
            Text("Start a conversation to see it here")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                createNewChat()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New Chat")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
    }
    
    // MARK: - Conversation List
    
    private var conversationList: some View {
        List {
            ForEach(conversationManager.conversations) { conversation in
                ConversationRow(
                    conversation: conversation,
                    isCurrentConversation: conversationManager.currentConversation?.id == conversation.id,
                    onSelect: {
                        selectConversation(conversation)
                    },
                    onRename: {
                        editingConversation = conversation
                        newTitle = conversation.title
                    },
                    onDelete: {
                        conversationToDelete = conversation
                        showingDeleteAlert = true
                    }
                )
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Actions
    
    private func createNewChat() {
        _ = conversationManager.createNewConversation()
        onNewChat()
        dismiss()
    }
    
    private func selectConversation(_ conversation: SavedConversation) {
        conversationManager.loadConversation(conversation)
        onSelectConversation(conversation)
        dismiss()
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: SavedConversation
    let isCurrentConversation: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onSelect()
            HapticManager.shared.playLightImpact()
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isCurrentConversation ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isCurrentConversation ? .accentColor : .secondary)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(conversation.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(conversation.messageCount == 1 ? "1 message" : "\(conversation.messageCount) messages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(conversation.lastUpdated, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Current indicator
                if isCurrentConversation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
        .contextMenu {
            Button {
                onRename()
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatHistoryView(
        onSelectConversation: { _ in },
        onNewChat: {}
    )
}
