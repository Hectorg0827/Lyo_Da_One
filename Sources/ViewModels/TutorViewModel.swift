
import Foundation
import SwiftUI
import Combine

@MainActor
final class TutorViewModel: ObservableObject {
    // MARK: - Published State
    @Published var session: TutorSession?
    @Published var messages: [TutorMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    let courseId: String
    let lessonId: String
    private let apiClient: LyoAPIClient
    
    // MARK: - Init
    init(courseId: String, lessonId: String, apiClient: LyoAPIClient = .shared) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.apiClient = apiClient
    }
    
    // MARK: - Actions
    
    func setupSession() async {
        guard session == nil else { return }
        
        do {
            let newSession = try await apiClient.createTutorSession(
                courseId: courseId,
                lessonId: lessonId
            )
            self.session = newSession
            await loadMessages(for: newSession.id)
        } catch {
            self.errorMessage = "Failed to start tutor session: \(error.localizedDescription)"
        }
    }
    
    func loadMessages(for sessionId: String) async {
        do {
            let msgs = try await apiClient.fetchTutorMessages(sessionId: sessionId)
            withAnimation(.easeInOut(duration: 0.3)) {
                self.messages = msgs
            }
        } catch {
            self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
        }
    }
    
    func send() async {
        guard let session = session else { return }
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Optimistic update
        let userMessage = TutorMessage(
            id: UUID().uuidString,
            sessionId: session.id,
            sender: "user",
            content: trimmed,
            createdAt: Date()
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(userMessage)
        }
        
        // Clear input immediately
        let contentToSend = trimmed
        inputText = ""
        isLoading = true
        
        do {
            let aiMsg = try await apiClient.sendTutorMessage(
                sessionId: session.id,
                content: contentToSend
            )
            
            isLoading = false
            withAnimation(.easeInOut(duration: 0.3)) {
                self.messages.append(aiMsg)
            }
        } catch {
            isLoading = false
            self.errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }
}
