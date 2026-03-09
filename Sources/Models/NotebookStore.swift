import Foundation
import SwiftUI
import Combine

struct NotebookEntry: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String?
    let text: String
    let sourceContext: String?
    let tags: [String]
    let color: String
    let createdAt: Date
    let updatedAt: Date
}

@MainActor
class NotebookStore: ObservableObject {
    @Published var notes: [NotebookEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // In Lyo architecture, we use AppConfig.baseURL
    private var apiBase: String { "\(AppConfig.baseURL)/api/v1/notebook" }
    
    func fetchNotes(userId: String = "test_user") async {
        self.isLoading = true
        guard let url = URL(string: "\(apiBase)/\(userId)") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            // Backend uses ISO8601 formatting and snake_case
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let fetchedNotes = try decoder.decode([NotebookEntry].self, from: data)
            self.notes = fetchedNotes
        } catch {
            print("Failed to fetch notes: \(error)")
        }
        self.isLoading = false
    }
    
    func saveNote(text: String, sourceContext: String? = nil, tags: [String] = [], userId: String = "test_user") async {
        guard let url = URL(string: apiBase) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use snake_case for the payload to match backend Pydantic model
        let payload: [String: Any] = [
            "user_id": userId,
            "text": text,
            "source_context": sourceContext ?? "Chat Highlight",
            "tags": tags,
            "color": "#FBBF24"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let newNote = try decoder.decode(NotebookEntry.self, from: data)
            
            self.notes.insert(newNote, at: 0)
        } catch {
            print("Failed to save note: \(error)")
            // Optimistic update fallback for prototype smoothness if backend is down
            let placeholder = NotebookEntry(
                id: UUID().uuidString, userId: userId, title: nil, text: text,
                sourceContext: sourceContext, tags: tags, color: "#FBBF24",
                createdAt: Date(), updatedAt: Date()
            )
            self.notes.insert(placeholder, at: 0)
        }
    }
    
    func deleteNote(noteId: String) async {
        guard let url = URL(string: "\(apiBase)/\(noteId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            _ = try await URLSession.shared.data(for: request)
            self.notes.removeAll(where: { $0.id == noteId })
        } catch {
            print("Failed to delete note: \(error)")
        }
    }
}
