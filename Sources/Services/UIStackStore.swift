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

    /// courseId (== the backend's content_id) → the real backend row id,
    /// populated as items are created/discovered this session. Lets
    /// `syncCourseProgressToBackend` PUT without doing a lookup on every
    /// single progress tick.
    private var backendItemIdsByCourseId: [String: Int] = [:]

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
        // Pull first: surfaces courses started on another device/platform
        // that this device has never seen locally. refreshCourseProgressFromBackend
        // below only refreshes items already known locally, so without this
        // a course started elsewhere would never appear here.
        await mergeCourseStacksFromBackend()
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
        syncCourseUpsertToBackend(courseId: courseId, title: title)
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

    /// Updates the local presentation immediately, then fires a non-
    /// blocking sync of this course's stack progress to the real backend
    /// (see syncCourseProgressToBackend below) — this is a separate write
    /// from the authoritative per-lesson completion endpoint
    /// (/learning/lesson-completions), which remains the source of truth
    /// for XP/mastery; this one only keeps the Stacks card's progress bar
    /// in sync across devices.
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
        syncCourseProgressToBackend(courseId: courseId, progress: item.progress ?? 0)
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

    // MARK: - Real Backend Sync (device- and platform-agnostic)
    //
    // UIStackStore's UserDefaults-backed `items` list is the fast, always-
    // available local presentation layer. These functions mirror course
    // items to/from the real, auth-gated `/api/v1/stack/items` backend —
    // the same contract Android's StackRepository.kt and web's
    // lib/stack.ts already sync against — so a course started on one
    // device/platform shows up on any other. Every call here is fire-and-
    // forget from the caller's perspective and swallows its own errors: a
    // failed sync must never crash or block the local UI, matching this
    // file's existing resilience pattern (refreshCourseProgressFromBackend
    // above already does the same).

    /// Pulls every course stack item this user has on the backend and
    /// merges any not already known locally into `items` — the actual
    /// cross-device surface. Without this, a course started on another
    /// device/platform would never appear here, since
    /// refreshCourseProgressFromBackend above only ever refreshes items it
    /// already knows about locally.
    func mergeCourseStacksFromBackend() async {
        guard let remoteItems = try? await repository.fetchCourseStackItems() else { return }

        await MainActor.run {
            for remote in remoteItems {
                guard let contentId = remote.contentId, !contentId.isEmpty else { continue }
                backendItemIdsByCourseId[contentId] = remote.id

                if let index = items.firstIndex(where: { $0.type == .course && $0.courseId == contentId }) {
                    var item = items[index]
                    item.progress = max(item.progress ?? 0, remote.progress)
                    if let updatedAt = remote.updatedAt, updatedAt > item.updatedAt {
                        item.updatedAt = updatedAt
                    }
                    items[index] = item
                } else {
                    // A course started on another device/platform, never
                    // seen locally before now.
                    items.append(UIStackItem(
                        type: .course,
                        title: remote.title,
                        updatedAt: remote.updatedAt ?? Date(),
                        progress: remote.progress,
                        courseId: contentId
                    ))
                }
            }
            sortByRecency()
            saveToDisk()
        }
    }

    /// Fire-and-forget: creates the backend stack item for this course if
    /// one doesn't already exist. The backend has no upsert-by-course
    /// semantics (`POST /items` always inserts — confirmed directly
    /// against lyo_app/stack/crud.py), so this does its own client-side
    /// "does one already exist" check first, exactly like Android's
    /// StackRepository.upsertCourseOnStart and web's lib/stack.ts's
    /// upsertCourseOnStart. Skips placeholder spaced-repetition review
    /// cards (courseId prefixed "GENERATE:"), which don't have a real
    /// backend course id yet — the same exclusion
    /// refreshCourseProgressFromBackend above already applies.
    private func syncCourseUpsertToBackend(courseId: String, title: String) {
        let trimmed = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("GENERATE:") else { return }

        Task {
            let alreadyKnown = await MainActor.run { backendItemIdsByCourseId[trimmed] != nil }
            if alreadyKnown { return }

            if let existing = try? await repository.fetchCourseStackItems().first(where: { $0.contentId == trimmed }) {
                await MainActor.run { backendItemIdsByCourseId[trimmed] = existing.id }
                return
            }

            guard let created = try? await repository.createCourseStackItem(title: title, contentId: trimmed) else { return }
            await MainActor.run { backendItemIdsByCourseId[trimmed] = created.id }
        }
    }

    /// Fire-and-forget progress sync. No-ops if this course's backend item
    /// id isn't known yet (the upsert above hasn't resolved) — the next
    /// mergeCourseStacksFromBackend or upsertCourse call catches it up;
    /// this never blocks or queues, matching every other sync path here.
    private func syncCourseProgressToBackend(courseId: String, progress: Double) {
        let trimmed = courseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("GENERATE:") else { return }

        Task {
            guard let backendId = await MainActor.run(body: { backendItemIdsByCourseId[trimmed] }) else { return }
            _ = try? await repository.updateCourseStackItemProgress(id: backendId, progress: progress)
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
