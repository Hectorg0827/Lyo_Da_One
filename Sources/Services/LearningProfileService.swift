import Foundation

/// Stage B1 — fetch + cache the user's learning profile so the chat can
/// reference past sessions, struggle topics, and known subjects without
/// re-asking every conversation.
///
/// Single-flight: concurrent `fetchIfNeeded()` calls share one in-flight
/// network request. The cached profile is exposed via `current` so views
/// can read it synchronously after the first fetch completes.
@MainActor
final class LearningProfileService: ObservableObject {

    static let shared = LearningProfileService()

    /// Most recent profile. `nil` until the first successful fetch.
    @Published private(set) var current: LearningProfile?

    /// True while a network fetch is in flight.
    @Published private(set) var isLoading: Bool = false

    private var inFlight: Task<LearningProfile?, Error>?
    private var lastFetchedAt: Date?
    private let staleAfter: TimeInterval = 120  // 2 minutes

    private init() {}

    // MARK: - Public API

    /// Fetch the profile if we don't have one or the cache is stale.
    /// Returns the latest profile (or nil if unauthenticated / endpoint fails).
    @discardableResult
    func fetchIfNeeded(force: Bool = false) async -> LearningProfile? {
        if !force,
           let current,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < staleAfter {
            return current
        }
        return try? await fetch()
    }

    /// Force a fetch and return the result. Throws on network error.
    @discardableResult
    func fetch() async throws -> LearningProfile? {
        if let inFlight {
            return try await inFlight.value
        }
        isLoading = true
        let task = Task<LearningProfile?, Error> { [weak self] in
            defer {
                Task { @MainActor in
                    self?.isLoading = false
                    self?.inFlight = nil
                }
            }
            do {
                let profile: LearningProfile = try await NetworkClient.shared.request(
                    Endpoints.LearningProfileAPI.get,
                    cachePolicy: .reloadIgnoringCache
                )
                await MainActor.run {
                    self?.current = profile
                    self?.lastFetchedAt = Date()
                }
                return profile
            } catch let error as LyoError {
                // Auth failures during the guest-session window are expected
                // and shouldn't pollute logs. Quietly leave `current` nil.
                if case .network(.unauthorized) = error {
                    return nil
                }
                throw error
            }
        }
        inFlight = task
        return try await task.value
    }

    /// Clear cached profile (e.g. on logout).
    func clear() {
        current = nil
        lastFetchedAt = nil
        inFlight?.cancel()
        inFlight = nil
    }

    /// Patch one or more fields. Updates cache on success.
    @discardableResult
    func update(_ payload: LearningProfileUpdate) async throws -> LearningProfile {
        let updated: LearningProfile = try await NetworkClient.shared.request(
            Endpoints.LearningProfileAPI.update(payload: payload),
            cachePolicy: .reloadIgnoringCache
        )
        current = updated
        lastFetchedAt = Date()
        return updated
    }

    // MARK: - Convenience writes

    /// Convenience: tell the server the user just opened a classroom session.
    func recordClassroomSession(topic: String?, sessionId: String?) {
        let payload = LearningProfileUpdate(
            lastClassroomTopic: topic,
            lastClassroomSessionId: sessionId,
            recordClassroomSession: true
        )
        Task {
            try? await update(payload)
        }
    }

    // MARK: - Chat context

    /// Compact context summary safe to splice into a system prompt or first
    /// user-facing greeting. Returns nil when the profile is empty.
    func chatContextLine() -> String? {
        guard let profile = current, profile.hasContext else { return nil }
        var parts: [String] = []
        if !profile.knownSubjects.isEmpty {
            parts.append("Subjects you've worked on: \(profile.knownSubjects.prefix(5).joined(separator: ", "))")
        }
        if !profile.struggleTopics.isEmpty {
            parts.append("Topics that have been challenging: \(profile.struggleTopics.prefix(3).joined(separator: ", "))")
        }
        if let topic = profile.lastClassroomTopic {
            parts.append("Last classroom session: \(topic)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }
}
