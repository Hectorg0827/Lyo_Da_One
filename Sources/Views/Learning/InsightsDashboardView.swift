import SwiftUI

/// Comprehensive Self-Evolution dashboard showing goals, risk, timing, interventions and proofs.
struct InsightsDashboardView: View {
    @StateObject private var vm = SelfEvolutionViewModel()
    @StateObject private var softSkills = SoftSkillsService.shared
    @StateObject private var memory = SmartMemoryService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Header
                evolutionHeader

                // MARK: - Risk & Momentum
                HStack(spacing: 12) {
                    riskCard
                    momentumCard
                }

                // MARK: - Next Upgrade
                if let upgrade = vm.nextUpgrade {
                    upgradeCard(upgrade)
                }

                // MARK: - Optimal Timing
                if let timing = vm.timingProfile {
                    timingCard(timing)
                }

                // MARK: - Interventions
                if !vm.interventions.isEmpty {
                    interventionsSection
                }

                // MARK: - Goals Summary
                goalsSummary

                // MARK: - Soft Skills
                if let profile = softSkills.profile {
                    softSkillsSection(profile)
                }

                // MARK: - Memory Insights
                if let mem = memory.memory, !mem.struggles.isEmpty {
                    memorySection(mem)
                }
            }
            .padding()
        }
        .navigationTitle("Self-Evolution")
        .task {
            await vm.loadAll()
            await softSkills.fetchProfile()
            await memory.fetchMemory()
        }
        .refreshable {
            await vm.loadAll()
        }
    }

    // MARK: - Sub-views

    private var evolutionHeader: some View {
        VStack(spacing: 4) {
            Text("🧬")
                .font(.system(size: 40))
            Text("Your Evolution")
                .font(.title.bold())
            Text("AI-powered insights into your learning journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var riskCard: some View {
        VStack(spacing: 6) {
            Text("Risk Level")
                .font(.caption)
                .foregroundColor(.secondary)
            Circle()
                .fill(vm.riskColor.opacity(0.2))
                .overlay(
                    Text(vm.dropoutRisk?.riskLevel.capitalized ?? "—")
                        .font(.caption.bold())
                        .foregroundColor(vm.riskColor)
                )
                .frame(width: 56, height: 56)
            if let score = vm.dropoutRisk?.riskScore {
                Text("\(Int(score * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private var momentumCard: some View {
        VStack(spacing: 6) {
            Text("Momentum")
                .font(.caption)
                .foregroundColor(.secondary)
            let momentum = vm.latestMomentum ?? 0
            Image(systemName: momentum >= 1.0 ? "arrow.up.right" : "arrow.right")
                .font(.title)
                .foregroundColor(momentum >= 1.0 ? .green : .orange)
            Text(String(format: "%.1f", momentum))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private func upgradeCard(_ upgrade: UpgradeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text("Recommended Next Action")
                    .font(.headline)
            }
            Text(upgrade.skillName)
                .font(.title3.bold())
            Text(upgrade.reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(14)
    }

    private func timingCard(_ timing: TimingProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                Text("Optimal Study Times")
                    .font(.headline)
            }
            let hours = timing.peakHours.map { "\($0):00" }.joined(separator: ", ")
            Text("Peak hours: \(hours)")
                .font(.subheadline)
            Text("Recommended session: \(timing.recommendedSessionLength) min")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.purple.opacity(0.08))
        .cornerRadius(14)
    }

    private var interventionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                Text("Smart Nudges")
                    .font(.headline)
            }
            ForEach(vm.interventions.prefix(3)) { item in
                HStack {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(item.message)
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
    }

    private var goalsSummary: some View {
        NavigationLink(destination: GoalsView()) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Goals")
                        .font(.headline)
                    Text("\(vm.activeGoals.count) active · \(vm.achievedGoals.count) achieved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func softSkillsSection(_ profile: SoftSkillsProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.teal)
                Text("Soft Skills")
                    .font(.headline)
            }
            skillBar("Critical Thinking", score: profile.criticalThinking.score)
            skillBar("Communication", score: profile.communication.score)
            skillBar("Grit", score: profile.grit.score)
            skillBar("Creativity", score: profile.creativity.score)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.teal.opacity(0.08))
        .cornerRadius(14)
    }

    private func skillBar(_ name: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.caption)
                Spacer()
                Text("\(Int(score))%").font(.caption2).foregroundColor(.secondary)
            }
            ProgressView(value: score, total: 100)
                .tint(.teal)
        }
    }

    private func memorySection(_ mem: LearningMemory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.indigo)
                Text("Memory Insights")
                    .font(.headline)
            }
            ForEach(mem.struggles.prefix(3)) { struggle in
                HStack {
                    Image(systemName: struggle.resolved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(struggle.resolved ? .green : .orange)
                        .font(.caption)
                    Text(struggle.topic)
                        .font(.subheadline)
                    Spacer()
                    Text("×\(struggle.frequency)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.indigo.opacity(0.08))
        .cornerRadius(14)
    }
}
