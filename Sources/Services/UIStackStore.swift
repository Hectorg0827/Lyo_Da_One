import Foundation
import Combine
import os

// MARK: - Stack Store

/// Manages the local UI stack of cards (courses, tutors, collabs, chats)
/// This is the user's "brain drawer" - all their active items in one place
final class UIStackStore: ObservableObject {
    static let shared = UIStackStore()
    
    @Published private(set) var items: [UIStackItem] = []
    
    private let userDefaultsKey = "lyo_ui_stack_items"
    private let repository = LyoRepository.shared
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Core Operations
    
    /// Add or update an item in the stack
    func upsert(_ item: UIStackItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        sortByRecency()
        saveToDisk()
    }
    
    /// Remove an item by ID
    func remove(id: String) {
        items.removeAll { $0.id == id }
        saveToDisk()
    }
    
    /// Clear all items
    func removeAll() {
        items.removeAll()
        saveToDisk()
    }
    
    /// Get items filtered by type
    func items(ofType type: UIStackItemType) -> [UIStackItem] {
        items.filter { $0.type == type }
    }
    
    // MARK: - Convenience Methods
    
    /// Add or update a course card
    func upsertCourse(
        courseId: String,
        title: String,
        subtitle: String? = nil,
        progress: Double? = nil,
        lessonCount: Int? = nil,
        completedLessons: Int? = nil
    ) {
        let existing = items.first { $0.type == .course && $0.courseId == courseId }
        let baseId = existing?.id ?? UUID().uuidString
        
        let item = UIStackItem(
            id: baseId,
            type: .course,
            title: title,
            subtitle: subtitle,
            updatedAt: Date(),
            progress: progress,
            courseId: courseId,
            lessonCount: lessonCount,
            completedLessons: completedLessons
        )
        upsert(item)
    }
    
    /// Add or update a tutor card (linked to a specific lesson)
    func upsertTutor(
        courseId: String,
        lessonId: String,
        courseTitle: String,
        lessonTitle: String,
        lastQuestion: String? = nil
    ) {
        let existing = items.first {
            $0.type == .tutor && $0.courseId == courseId && $0.lessonId == lessonId
        }
        let baseId = existing?.id ?? UUID().uuidString
        
        let item = UIStackItem(
            id: baseId,
            type: .tutor,
            title: "Tutor: \(lessonTitle)",
            subtitle: courseTitle,
            updatedAt: Date(),
            courseId: courseId,
            lessonId: lessonId,
            lastMessage: lastQuestion
        )
        upsert(item)
    }
    
    /// Add or update a collab room card
    func upsertCollab(
        roomId: String,
        title: String,
        subtitle: String? = nil,
        participantCount: Int? = nil
    ) {
        let existing = items.first {
            $0.type == .collab && $0.collabRoomId == roomId
        }
        let baseId = existing?.id ?? UUID().uuidString
        
        let item = UIStackItem(
            id: baseId,
            type: .collab,
            title: title,
            subtitle: subtitle ?? "Live room",
            updatedAt: Date(),
            collabRoomId: roomId,
            participantCount: participantCount
        )
        upsert(item)
    }
    
    /// Add or update a chat card
    func upsertChat(
        key: String,
        title: String,
        subtitle: String? = nil,
        lastMessage: String? = nil
    ) {
        let existing = items.first {
            $0.type == .chat && $0.chatKey == key
        }
        let baseId = existing?.id ?? UUID().uuidString
        
        let item = UIStackItem(
            id: baseId,
            type: .chat,
            title: title,
            subtitle: subtitle,
            updatedAt: Date(),
            chatKey: key,
            lastMessage: lastMessage
        )
        upsert(item)
    }
    
    /// Update progress for a course
    func updateCourseProgress(courseId: String, progress: Double, completedLessons: Int? = nil) {
        guard let index = items.firstIndex(where: { $0.type == .course && $0.courseId == courseId }) else {
            return
        }
        
        var item = items[index]
        item.progress = progress
        item.updatedAt = Date()
        if let completed = completedLessons {
            item.completedLessons = completed
        }
        items[index] = item
        sortByRecency()
        saveToDisk()
        
        // 🔥 BACKEND SYNC: Sync progress to backend for cross-device support
        Task {
            await syncCourseProgressToBackend(courseId: courseId, progress: progress)
        }
    }
    
    // MARK: - Backend Sync
    
    /// Sync course progress to backend (called automatically on updateCourseProgress)
    private func syncCourseProgressToBackend(courseId: String, progress: Double) async {
        do {
            let _: EmptyResponse = try await NetworkClient.shared.request(
                Endpoints.Analytics.trackLearningProgress(
                    contentId: courseId,
                    progress: progress,
                    timeSpent: 0,
                    sessionId: nil
                )
            )
            Log.net.info("UIStackStore: Synced course progress to backend (\(Int(progress * 100))%)")
        } catch {
            Log.net.warning("UIStackStore: Failed to sync course progress: \(error.localizedDescription)")
            // Don't block user - local tracking continues
        }
    }
    
    // MARK: - Private Helpers
    
    private func sortByRecency() {
        items.sort { $0.updatedAt > $1.updatedAt }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Log.net.error("UIStackStore: Failed to save to disk: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }
        
        do {
            items = try JSONDecoder().decode([UIStackItem].self, from: data)
            sortByRecency()
        } catch {
            Log.net.error("UIStackStore: Failed to load from disk: \(error)")
        }
    }
}
