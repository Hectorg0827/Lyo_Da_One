import Foundation
import SwiftUI

struct NotebookEntry: Identifiable, Codable, Equatable {
    let id: String
    let conversationId: String
    let messageId: String
    let text: String
    let sourceContext: String?
    let color: String
    let createdAt: Date
    let updatedAt: Date
}

struct ChatHighlight: Identifiable, Codable, Equatable {
    let id: String
    let messageId: String
    let selectedText: String
    let location: Int
    let length: Int
    let color: String
    let createdAt: Date
}

private struct NotebookPersistenceSnapshot: Codable {
    var notesByConversation: [String: [NotebookEntry]]
    var highlightsByConversation: [String: [String: [ChatHighlight]]]
}

@MainActor
class NotebookStore: ObservableObject {
    @Published private(set) var notes: [NotebookEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String? = nil
    @Published private(set) var activeConversationId: String?
    @Published private(set) var activeHighlightsByMessage: [String: [ChatHighlight]] = [:]

    private let persistenceKey = "lyo_chat_annotations_v2"
    private var notesByConversation: [String: [NotebookEntry]] = [:]
    private var highlightsByConversation: [String: [String: [ChatHighlight]]] = [:]

    init() {
        restore()
    }

    var hasNotesInActiveConversation: Bool {
        !notes.isEmpty
    }

    func activateConversation(_ conversationId: String) {
        activeConversationId = conversationId
        notes = notesByConversation[conversationId, default: []]
            .sorted { $0.createdAt > $1.createdAt }
        activeHighlightsByMessage = highlightsByConversation[conversationId, default: [:]]
        errorMessage = nil
    }

    func highlights(for messageId: String) -> [ChatHighlight] {
        activeHighlightsByMessage[messageId, default: []]
            .sorted { lhs, rhs in
                if lhs.location == rhs.location {
                    return lhs.length < rhs.length
                }
                return lhs.location < rhs.location
            }
    }

    func saveNote(
        text: String,
        messageId: String,
        sourceContext: String? = nil,
        color: String = "#34D399"
    ) {
        guard let conversationId = activeConversationId else {
            errorMessage = "No active conversation for note."
            return
        }

        let trimmed = sanitize(text)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        let entry = NotebookEntry(
            id: UUID().uuidString,
            conversationId: conversationId,
            messageId: messageId,
            text: trimmed,
            sourceContext: sourceContext,
            color: color,
            createdAt: now,
            updatedAt: now
        )

        var conversationNotes = notesByConversation[conversationId, default: []]
        conversationNotes.insert(entry, at: 0)
        notesByConversation[conversationId] = conversationNotes
        notes = conversationNotes
        persist()
    }

    func saveHighlight(
        text: String,
        range: NSRange,
        messageId: String,
        color: String = "#FBBF24"
    ) {
        guard let conversationId = activeConversationId else {
            errorMessage = "No active conversation for highlight."
            return
        }

        let trimmed = sanitize(text)
        guard !trimmed.isEmpty, range.location != NSNotFound, range.length > 0 else { return }

        var conversationHighlights = highlightsByConversation[conversationId, default: [:]]
        var messageHighlights = conversationHighlights[messageId, default: []]

        let alreadyExists = messageHighlights.contains {
            $0.location == range.location && $0.length == range.length && $0.selectedText == trimmed
        }
        guard !alreadyExists else { return }

        messageHighlights.append(
            ChatHighlight(
                id: UUID().uuidString,
                messageId: messageId,
                selectedText: trimmed,
                location: range.location,
                length: range.length,
                color: color,
                createdAt: Date()
            )
        )

        conversationHighlights[messageId] = messageHighlights
        highlightsByConversation[conversationId] = conversationHighlights
        activeHighlightsByMessage = conversationHighlights
        persist()
    }

    func deleteNote(noteId: String) {
        guard let conversationId = activeConversationId else { return }

        var conversationNotes = notesByConversation[conversationId, default: []]
        conversationNotes.removeAll { $0.id == noteId }
        notesByConversation[conversationId] = conversationNotes
        notes = conversationNotes
        persist()
    }

    private func sanitize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(NotebookPersistenceSnapshot.self, from: data)
            notesByConversation = snapshot.notesByConversation
            highlightsByConversation = snapshot.highlightsByConversation
        } catch {
            errorMessage = "Unable to restore chat notes."
            print("❌ Failed to restore chat annotations: \(error)")
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let snapshot = NotebookPersistenceSnapshot(
                notesByConversation: notesByConversation,
                highlightsByConversation: highlightsByConversation
            )
            let data = try encoder.encode(snapshot)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            errorMessage = "Unable to save chat notes."
            print("❌ Failed to persist chat annotations: \(error)")
        }
    }
}
