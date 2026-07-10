import Foundation

/// Stage B2 — fetch + cache the user's persistent study plans.
///
/// Mirrors the shape of `LearningProfileService` (single-flight, MainActor,
/// silent on unauth). Plans created from chat go through `create(_:)` which
/// updates the cache so the chat-context line stays current immediately.
@MainActor
final class StudyPlanService: ObservableObject {

    static let shared = StudyPlanService()

    /// Active plans, freshest first. nil until first successful fetch.
    @Published private(set) var activePlans: [StudyPlanRecord] = []

    @Published private(set) var isLoading: Bool = false

    private var inFlight: Task<[StudyPlanRecord], Error>?
    private var lastFetchedAt: Date?
    private let staleAfter: TimeInterval = 120

    private init() {}

    // MARK: - Read

    @discardableResult
    func fetchIfNeeded(force: Bool = false) async -> [StudyPlanRecord] {
        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < staleAfter {
            return activePlans
        }
        return (try? await fetch()) ?? activePlans
    }

    @discardableResult
    func fetch() async throws -> [StudyPlanRecord] {
        if let inFlight {
            return try await inFlight.value
        }
        isLoading = true
        let task = Task<[StudyPlanRecord], Error> { [weak self] in
            defer {
                Task { @MainActor in
                    self?.isLoading = false
                    self?.inFlight = nil
                }
            }
            do {
                let plans: [StudyPlanRecord] = try await NetworkClient.shared.request(
                    Endpoints.StudyPlansAPI.list(includeCompleted: false),
                    cachePolicy: .reloadIgnoringCache
                )
                await MainActor.run {
                    self?.activePlans = plans
                    self?.lastFetchedAt = Date()
                }
                return plans
            } catch let error as LyoError {
                if case .network(.unauthorized) = error {
                    return []
                }
                throw error
            }
        }
        inFlight = task
        return try await task.value
    }

    // MARK: - Write

    @discardableResult
    func create(_ payload: StudyPlanRecordCreate) async throws -> StudyPlanRecord {
        let plan: StudyPlanRecord = try await NetworkClient.shared.request(
            Endpoints.StudyPlansAPI.create(payload: payload),
            cachePolicy: .reloadIgnoringCache
        )
        // Insert at the front so it's surfaced first.
        activePlans.insert(plan, at: 0)
        lastFetchedAt = Date()
        return plan
    }

    @discardableResult
    func update(id: Int, payload: StudyPlanRecordUpdate) async throws -> StudyPlanRecord {
        let updated: StudyPlanRecord = try await NetworkClient.shared.request(
            Endpoints.StudyPlansAPI.update(id: id, payload: payload),
            cachePolicy: .reloadIgnoringCache
        )
        if let idx = activePlans.firstIndex(where: { $0.id == id }) {
            if updated.status == .active {
                activePlans[idx] = updated
            } else {
                // Status moved off-active — drop from active list.
                activePlans.remove(at: idx)
            }
        }
        lastFetchedAt = Date()
        return updated
    }

    func delete(id: Int) async throws {
        struct Empty: Codable {}
        let _: Empty? = try? await NetworkClient.shared.request(
            Endpoints.StudyPlansAPI.delete(id: id),
            cachePolicy: .reloadIgnoringCache
        )
        activePlans.removeAll { $0.id == id }
    }

    // MARK: - Chat context

    /// Compact context line listing active plans. Returns nil when none.
    /// Spliced into the AI request alongside the LearningProfile context.
    func chatContextLine() -> String? {
        guard !activePlans.isEmpty else { return nil }
        // Show at most the 2 most-recent plans to keep the prompt focused.
        let lines = activePlans.prefix(2).map { $0.contextLine }
        return lines.joined(separator: " | ")
    }

    func clear() {
        activePlans = []
        lastFetchedAt = nil
        inFlight?.cancel()
        inFlight = nil
    }
}
