import Foundation
import os

// MARK: - Evolution Models

struct UserGoal: Codable, Identifiable {
    let id: Int
    let userId: Int
    let target: String
    let description: String?
    let status: GoalStatus
    let targetDate: Date?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let skillMappings: [GoalSkillMapping]
    let progressSnapshots: [GoalProgressSnapshot]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case target, description, status
        case targetDate = "target_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case skillMappings = "skill_mappings"
        case progressSnapshots = "progress_snapshots"
    }
}

enum GoalStatus: String, Codable {
    case active = "active"
    case achieved = "achieved"
    case abandoned = "abandoned"
    case paused = "paused"
}

struct GoalSkillMapping: Codable, Identifiable {
    let id: Int
    let goalId: Int
    let skillId: Int
    let importanceWeight: Double

    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case skillId = "skill_id"
        case importanceWeight = "importance_weight"
    }
}

struct GoalProgressSnapshot: Codable, Identifiable {
    let id: Int
    let goalId: Int
    let overallCompletionPercentage: Double
    let momentumScore: Double
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case goalId = "goal_id"
        case overallCompletionPercentage = "overall_completion_percentage"
        case momentumScore = "momentum_score"
        case recordedAt = "recorded_at"
    }
}

struct UpgradeSuggestion: Codable {
    let skillId: Int
    let skillName: String
    let domain: String
    let reason: String
    let recommendedAction: String
    let priorityScore: Double
    let type: String

    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case skillName = "skill_name"
        case domain, reason
        case recommendedAction = "recommended_action"
        case priorityScore = "priority_score"
        case type
    }
}

struct UpgradeResponse: Codable {
    let suggestion: UpgradeSuggestion?
    let message: String?
}

struct ReflectionResponse: Codable {
    let status: String
    let eventId: Int
    let confidenceNormalized: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case eventId = "event_id"
        case confidenceNormalized = "confidence_normalized"
    }
}

// MARK: - Request Bodies

struct CreateGoalRequest: Encodable {
    let target: String
    let description: String?
    let targetDate: String?
    let skillIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case target, description
        case targetDate = "target_date"
        case skillIds = "skill_ids"
    }
}

struct UpdateGoalStatusRequest: Encodable {
    let newStatus: String

    enum CodingKeys: String, CodingKey {
        case newStatus = "new_status"
    }
}

struct SkillMappingRequest: Encodable {
    let skillId: Int
    let importanceWeight: Double

    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case importanceWeight = "importance_weight"
    }
}

struct ProgressSnapshotRequest: Encodable {
    let overallCompletionPercentage: Double
    let momentumScore: Double

    enum CodingKeys: String, CodingKey {
        case overallCompletionPercentage = "overall_completion_percentage"
        case momentumScore = "momentum_score"
    }
}

struct ReflectionRequest: Encodable {
    let userId: Int
    let skillIds: [Int]
    let confidenceRating: Int
    let difficultyRating: Int
    let emotionalState: String
    let qualitativeNotes: String?
    let obstaclesIdentified: [String]?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case skillIds = "skill_ids"
        case confidenceRating = "confidence_rating"
        case difficultyRating = "difficulty_rating"
        case emotionalState = "emotional_state"
        case qualitativeNotes = "qualitative_notes"
        case obstaclesIdentified = "obstacles_identified"
    }
}

struct LearningEventRequest: Encodable {
    let userId: Int
    let eventType: String
    let skillIdsJson: [Int]?
    let metadataJson: [String: String]?
    let measurableOutcome: Double?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventType = "event_type"
        case skillIdsJson = "skill_ids_json"
        case metadataJson = "metadata_json"
        case measurableOutcome = "measurable_outcome"
    }
}

// MARK: - Predictive Models

struct DropoutRisk: Codable {
    let riskLevel: String
    let riskScore: Double
    let riskFactors: [String]
    let recommendations: [String]

    enum CodingKeys: String, CodingKey {
        case riskLevel = "risk_level"
        case riskScore = "risk_score"
        case riskFactors = "risk_factors"
        case recommendations
    }
}

struct TimingProfile: Codable {
    let peakHours: [Int]
    let recommendedSessionLength: Int
    let bestDays: [String]

    enum CodingKeys: String, CodingKey {
        case peakHours = "peak_hours"
        case recommendedSessionLength = "recommended_session_length"
        case bestDays = "best_days"
    }
}

struct InterventionItem: Codable, Identifiable {
    let id: String
    let type: String
    let message: String
    let priority: Double
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, message, priority
        case createdAt = "created_at"
    }
}

struct InterventionsResponse: Codable {
    let interventions: [InterventionItem]
}

// MARK: - Evolution Service

@MainActor
final class EvolutionService: ObservableObject {
    static let shared = EvolutionService()

    @Published var goals: [UserGoal] = []
    @Published var nextUpgrade: UpgradeSuggestion?
    @Published var dropoutRisk: DropoutRisk?
    @Published var timingProfile: TimingProfile?
    @Published var interventions: [InterventionItem] = []
    @Published var isLoading = false

    // MARK: - Goals

    func fetchGoals(statusFilter: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        let endpoint = Endpoints.Evolution.listGoals(statusFilter: statusFilter)
        do {
            goals = try await NetworkClient.shared.request(endpoint)
        } catch {
            Log.net.warning("📊 Failed to fetch goals: \(error)")
        }
    }

    func createGoal(target: String, description: String? = nil, targetDate: String? = nil, skillIds: [Int]? = nil) async -> Bool {
        let body = CreateGoalRequest(target: target, description: description, targetDate: targetDate, skillIds: skillIds)
        let endpoint = Endpoints.Evolution.createGoal(body: body)
        do {
            let _: UserGoal = try await NetworkClient.shared.request(endpoint)
            await fetchGoals()
            return true
        } catch {
            Log.net.warning("📊 Failed to create goal: \(error)")
            return false
        }
    }

    func updateGoalStatus(goalId: Int, status: GoalStatus) async -> Bool {
        let body = UpdateGoalStatusRequest(newStatus: status.rawValue)
        let endpoint = Endpoints.Evolution.updateGoalStatus(goalId: goalId, body: body)
        do {
            let _: UserGoal = try await NetworkClient.shared.request(endpoint)
            await fetchGoals()
            return true
        } catch {
            Log.net.warning("📊 Failed to update goal: \(error)")
            return false
        }
    }

    func deleteGoal(goalId: Int) async -> Bool {
        let endpoint = Endpoints.Evolution.deleteGoal(goalId: goalId)
        do {
            let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
            goals.removeAll { $0.id == goalId }
            return true
        } catch {
            Log.net.warning("📊 Failed to delete goal: \(error)")
            return false
        }
    }

    // MARK: - Reflections

    func submitReflection(skillIds: [Int], confidence: Int, difficulty: Int, emotion: String, notes: String? = nil, obstacles: [String]? = nil) async -> Bool {
        let body = ReflectionRequest(
            userId: 0, // Overridden server-side
            skillIds: skillIds,
            confidenceRating: confidence,
            difficultyRating: difficulty,
            emotionalState: emotion,
            qualitativeNotes: notes,
            obstaclesIdentified: obstacles
        )
        let endpoint = Endpoints.Evolution.submitReflection(body: body)
        do {
            let _: ReflectionResponse = try await NetworkClient.shared.request(endpoint)
            return true
        } catch {
            Log.net.warning("📊 Failed to submit reflection: \(error)")
            return false
        }
    }

    // MARK: - Events

    func logEvent(eventType: String, skillIds: [Int]? = nil, outcome: Double? = nil) async {
        let body = LearningEventRequest(
            userId: 0, // Overridden server-side
            eventType: eventType,
            skillIdsJson: skillIds,
            metadataJson: nil,
            measurableOutcome: outcome
        )
        let endpoint = Endpoints.Evolution.logEvent(body: body)
        do {
            let _: LearningEventResponse = try await NetworkClient.shared.request(endpoint)
        } catch {
            Log.net.warning("📊 Failed to log event: \(error)")
        }
    }

    // MARK: - Recommendations

    func fetchNextUpgrade() async {
        let endpoint = Endpoints.Evolution.nextUpgrade
        do {
            let response: UpgradeResponse = try await NetworkClient.shared.request(endpoint)
            nextUpgrade = response.suggestion
        } catch {
            Log.net.warning("📊 Failed to fetch next upgrade: \(error)")
        }
    }

    // MARK: - Predictive

    func fetchDropoutRisk() async {
        let endpoint = Endpoints.Predictive.dropoutRisk
        do {
            dropoutRisk = try await NetworkClient.shared.request(endpoint)
        } catch {
            Log.net.warning("📊 Failed to fetch dropout risk: \(error)")
        }
    }

    func fetchTimingProfile() async {
        let endpoint = Endpoints.Predictive.timingProfile
        do {
            timingProfile = try await NetworkClient.shared.request(endpoint)
        } catch {
            Log.net.warning("📊 Failed to fetch timing profile: \(error)")
        }
    }

    // MARK: - Proactive Interventions

    func fetchInterventions() async {
        let endpoint = Endpoints.Proactive.getInterventions
        do {
            let response: InterventionsResponse = try await NetworkClient.shared.request(endpoint)
            interventions = response.interventions
        } catch {
            Log.net.warning("📊 Failed to fetch interventions: \(error)")
        }
    }
}

// MARK: - Helper Types

private struct EmptyResponse: Codable {}

private struct LearningEventResponse: Codable {
    let id: Int
}
