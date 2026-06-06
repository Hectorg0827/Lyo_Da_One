import SwiftUI

/// Goals management view — create, track, and complete learning goals.
struct GoalsView: View {
    @StateObject private var vm = SelfEvolutionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Next Upgrade Card
                if let upgrade = vm.nextUpgrade {
                    nextUpgradeCard(upgrade)
                }

                // MARK: - Active Goals
                Section {
                    if vm.activeGoals.isEmpty {
                        emptyGoalsPlaceholder
                    } else {
                        ForEach(vm.activeGoals) { goal in
                            GoalCard(goal: goal, onAchieve: {
                                Task { await vm.achieveGoal(goal) }
                            }, onAbandon: {
                                Task { await vm.abandonGoal(goal) }
                            })
                        }
                    }
                } header: {
                    sectionHeader("Active Goals", count: vm.activeGoals.count)
                }

                // MARK: - Achieved Goals
                if !vm.achievedGoals.isEmpty {
                    Section {
                        ForEach(vm.achievedGoals) { goal in
                            GoalCard(goal: goal, onAchieve: nil, onAbandon: nil)
                        }
                    } header: {
                        sectionHeader("Achieved 🏆", count: vm.achievedGoals.count)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("My Goals")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { vm.showCreateGoal = true } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $vm.showCreateGoal) {
            createGoalSheet
        }
        .task { await vm.loadAll() }
        .refreshable { await vm.loadAll() }
        .overlay {
            if vm.isLoading && vm.goals.isEmpty {
                ProgressView("Loading goals…")
            }
        }
    }

    // MARK: - Sub-views

    private func nextUpgradeCard(_ upgrade: UpgradeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text("Next Upgrade")
                    .font(.headline)
            }
            Text(upgrade.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(upgrade.skillName)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(16)
    }

    private var emptyGoalsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No active goals yet")
                .font(.headline)
            Text("Set a goal to start tracking your self-evolution journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.title2.bold())
            Spacer()
            Text("\(count)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(Capsule())
        }
    }

    private var createGoalSheet: some View {
        NavigationStack {
            Form {
                Section("What do you want to achieve?") {
                    TextField("e.g. Master Swift concurrency", text: $vm.newGoalTarget)
                    TextField("Description (optional)", text: $vm.newGoalDescription)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.showCreateGoal = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await vm.createGoal() {
                                vm.showCreateGoal = false
                            }
                        }
                    }
                    .disabled(vm.newGoalTarget.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Goal Card

private struct GoalCard: View {
    let goal: UserGoal
    let onAchieve: (() -> Void)?
    let onAbandon: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                statusIcon
                Text(goal.target)
                    .font(.headline)
                Spacer()
                if let latest = goal.progressSnapshots.last {
                    Text("\(Int(latest.overallCompletionPercentage))%")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
                }
            }

            if let desc = goal.description {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            if let latest = goal.progressSnapshots.last {
                ProgressView(value: latest.overallCompletionPercentage, total: 100)
                    .tint(progressColor(latest.momentumScore))
            }

            // Actions
            if goal.status == .active, let onAchieve, let onAbandon {
                HStack {
                    Button(action: onAchieve) {
                        Label("Complete", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Spacer()

                    Button(role: .destructive, action: onAbandon) {
                        Label("Remove", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    private var statusIcon: some View {
        Group {
            switch goal.status {
            case .active:
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
            case .achieved:
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
            case .abandoned:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.gray)
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func progressColor(_ momentum: Double) -> Color {
        if momentum >= 1.5 { return .green }
        if momentum >= 0.8 { return .blue }
        return .orange
    }
}
