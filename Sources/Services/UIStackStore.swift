import Foundation
import Combine

// MARK: - Stack Store

/// Manages the local UI stack of cards (courses, tutors, collabs, chats)
/// This is the user's "brain drawer" - all their active items in one place.
final class UIStackStore: ObservableObject {
    static let shared = UIStackStore()

    @Published private(set) var items: [UIStackItem] = []

    private let userDefaultsKey = "lyo_ui_stack_items"
    private let repository = LyoRepository.shared

    private init() {
        loadFromDisk()
    }

    // MARK: - Core Operations

    /// Add or update an item in the stack.
    func upsert(_ item: UIStackItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
        sortByRecency()
        saveToDisk()
    }

    /// Remove an item by ID.
    func remove(id: String) {
        items.removeAll { $0.id == id }
        saveToDisk()
    }

    /// Clear all items.
    func removeAll() {
        items.removeAll()
        saveToDisk()
    }

    /// Get items filtered by type.
    func items(ofType type: UIStackItemType) -> [UIStackItem] {
        items.filter { $0.type == type }
    }

    // MARK: - Spaced-Repetition Reviews

    /// Refreshes canonical server progress first, then asks the personalization
    /// engine whether spaced-repetition reviews are due.
    func refreshDueReviews() async {
        await refreshCourseProgressFromBackend()

        // Fetch the profile first — it also powers the weekly weakness quest,
        // which should refresh whether or not reviews are due.
        guard let profile = try? await PersonalizationService.shared.getMasteryProfile()
        else { return }

        await MainActor.run {
            GamificationService.shared.refreshWeeklyQuest(
                weaknesses: profile.recommendedFocus.isEmpty
                    ? profile.weaknesses : profile.recommendedFocus
            )
        }

        guard let next = try? await PersonalizationService.shared.getNextAction(),
              next.spacedRepetitionDue == true || next.action == .review
        else { return }

        let focus = profile.recommendedFocus.isEmpty ? profile.weaknesses : profile.recommendedFocus
        let skills = focus
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2)
        guard !skills.isEmpty else { return }

        await MainActor.run {
            for skill in skills {
                upsertCourse(
                    courseId: "GENERATE:\(skill)",
                    title: "Review: \(skill.capitalized)",
                    subtitle: "Due for a quick refresher"
                )
            }
        }
    }

    // MARK: - Convenience Methods

    /// Add or update a course card.
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
            progress: progress ?? existing?.progress,
            courseId: courseId,
            lessonCount: lessonCount ?? existing?.lessonCount,
            completedLessons: completedLessons ?? existing?.completedLessons
        )
        upsert(item)
    }

    /// Add or update a tutor card (linked to a specific lesson).
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

    /// Add or update a collab room card.
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

    /// Add or update a chat card.
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

    /// Updates the local presentation immediately. Server writes must happen
    /// through an explicit lesson-completion endpoint; a GET request is never
    /// treated as a successful progress write.
    func updateCourseProgress(courseId: String, progress: Double, completedLessons: Int? = nil) {
        guard let index = items.firstIndex(where: { $0.type == .course && $0.courseId == courseId }) else {
            return
        }

        var item = items[index]
        item.progress = max(0, min(progress, 1))
        item.updatedAt = Date()
        if let completed = completedLessons {
            item.completedLessons = completed
        }
        items[index] = item
        sortByRecency()
        saveToDisk()
    }

    // MARK: - Backend Hydration

    /// Reconciles saved course cards with the canonical server progress model.
    /// Generated/offline sessions are intentionally excluded because they do not
    /// have a persistent backend course identifier yet.
    func refreshCourseProgressFromBackend() async {
        let courseIds = Array(Set(items.compactMap { item -> String? in
            guard item.type == .course,
                  let courseId = item.courseId?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !courseId.isEmpty,
                  !courseId.hasPrefix("GENERATE:") else {
                return nil
            }
            return courseId
        }))

        for courseId in courseIds {
            do {
                let serverProgress = try await repository.getCourseProgress(courseId: courseId)
                let normalizedProgress = serverProgress.progressPercent > 1
                    ? serverProgress.progressPercent / 100
                    : serverProgress.progressPercent

                await MainActor.run {
                    guard let index = items.firstIndex(where: {
                        $0.type == .course && $0.courseId == courseId
                    }) else { return }

                    var item = items[index]
                    item.progress = max(0, min(normalizedProgress, 1))
                    item.lessonCount = serverProgress.totalLessons
                    item.completedLessons = serverProgress.completedLessons
                    if let lastAccessedAt = serverProgress.lastAccessedAt {
                        item.updatedAt = lastAccessedAt
                    }
                    items[index] = item
                    sortByRecency()
                    saveToDisk()
                }
            } catch {
                // Offline or unavailable progress must not erase the local state.
                print("UIStackStore: Server progress unavailable for \(courseId): \(error.localizedDescription)")
            }
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
            print("UIStackStore: Failed to save to disk: \(error)")
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
            print("UIStackStore: Failed to load from disk: \(error)")
        }
    }
}
