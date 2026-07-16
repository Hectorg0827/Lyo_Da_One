import Foundation
import SwiftUI

/// ViewModel coordinating the Self-Evolution dashboard:
/// Goals, Next Upgrade, Dropout Risk, Timing Profile, Interventions
@MainActor
final class SelfEvolutionViewModel: ObservableObject {
    @Published var goals: [UserGoal] = []
    @Published var nextUpgrade: UpgradeSuggestion?
    @Published var dropoutRisk: DropoutRisk?
    @Published var timingProfile: TimingProfile?
    @Published var interventions: [InterventionItem] = []
    @Published var isLoading = false
    @Published var showCreateGoal = false

    // Form state for new goal
    @Published var newGoalTarget = ""
    @Published var newGoalDescription = ""

    private let service = EvolutionService.shared

    func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        async let goalsTask: () = service.fetchGoals()
        async let upgradeTask: () = service.fetchNextUpgrade()
        async let riskTask: () = service.fetchDropoutRisk()
        async let timingTask: () = service.fetchTimingProfile()
        async let interventionsTask: () = service.fetchInterventions()

        _ = await (goalsTask, upgradeTask, riskTask, timingTask, interventionsTask)

        goals = service.goals
        nextUpgrade = service.nextUpgrade
        dropoutRisk = service.dropoutRisk
        timingProfile = service.timingProfile
        interventions = service.interventions
    }

    func createGoal() async -> Bool {
        guard !newGoalTarget.isEmpty else { return false }
        let success = await service.createGoal(
            target: newGoalTarget,
            description: newGoalDescription.isEmpty ? nil : newGoalDescription
        )
        if success {
            newGoalTarget = ""
            newGoalDescription = ""
            goals = service.goals
        }
        return success
    }

    func achieveGoal(_ goal: UserGoal) async {
        _ = await service.updateGoalStatus(goalId: goal.id, status: .achieved)
        goals = service.goals
    }

    func abandonGoal(_ goal: UserGoal) async {
        _ = await service.deleteGoal(goalId: goal.id)
        goals = service.goals
    }

    var activeGoals: [UserGoal] { goals.filter { $0.status == .active } }
    var achievedGoals: [UserGoal] { goals.filter { $0.status == .achieved } }

    var riskColor: Color {
        guard let risk = dropoutRisk else { return .gray }
        switch risk.riskLevel {
        case "low": return .green
        case "medium": return .orange
        case "high", "critical": return .red
        default: return .gray
        }
    }

    var latestMomentum: Double? {
        goals.compactMap { $0.progressSnapshots.last?.momentumScore }.first
    }
}
