//
//  CourseGenerationSettingsView.swift
//  Lyo
//
//  Settings view for configuring course generation options
//

import SwiftUI
import os

struct CourseGenerationSettingsView: View {
    @Binding var options: CourseGenerationOptions
    @State private var costEstimate: CostEstimate?
    @State private var isLoadingEstimate = false
    @State private var showBudgetInput = false
    
    let topic: String
    let onGenerate: (CourseGenerationOptions) -> Void
    
    var body: some View {
        Form {
            // Quality Tier Selection
            Section {
                Picker("Quality Tier", selection: $options.qualityTier) {
                    ForEach(QualityTier.allCases.filter { $0 != .custom }, id: \.self) { tier in
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tier.displayName)
                                    .font(.headline)
                                Text(tier.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: tier.icon)
                                .foregroundStyle(tierColor(tier))
                        }
                        .tag(tier)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: options.qualityTier) { _, _ in
                    fetchCostEstimate()
                }
            } header: {
                Text("Quality & Speed")
            } footer: {
                Text(options.qualityTier.description)
            }
            
            // Feature Toggles
            Section("Content Options") {
                Toggle(isOn: $options.includeCodeExamples) {
                    Label("Code Examples", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .onChange(of: options.includeCodeExamples) { _, _ in fetchCostEstimate() }
                
                Toggle(isOn: $options.includePracticeExercises) {
                    Label("Practice Exercises", systemImage: "pencil.and.list.clipboard")
                }
                .onChange(of: options.includePracticeExercises) { _, _ in fetchCostEstimate() }
                
                Toggle(isOn: $options.includeFinalQuiz) {
                    Label("Final Assessment", systemImage: "checkmark.seal")
                }
                .onChange(of: options.includeFinalQuiz) { _, _ in fetchCostEstimate() }
                
                Toggle(isOn: $options.includeMultimediaSuggestions) {
                    Label("Media Suggestions", systemImage: "photo.on.rectangle")
                }
            }
            
            // QA Strictness
            Section {
                Picker("QA Strictness", selection: $options.qaStrictness) {
                    Text("Lenient").tag("lenient")
                    Text("Standard").tag("standard")
                    Text("Strict").tag("strict")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Quality Control")
            } footer: {
                Text("Stricter QA may increase generation time but ensures higher accuracy")
            }
            
            // Budget Control
            Section {
                Toggle("Set Budget Cap", isOn: $showBudgetInput)
                
                if showBudgetInput {
                    HStack {
                        Text("Max Budget:")
                        Spacer()
                        TextField("Amount", value: $options.maxBudgetUSD, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            } header: {
                Text("Budget")
            } footer: {
                if let budget = options.maxBudgetUSD {
                    Text("Generation will not exceed $\(budget, specifier: "%.2f")")
                }
            }
            
            // Cost Estimate
            Section {
                if isLoadingEstimate {
                    HStack {
                        ProgressView()
                        Text("Calculating cost...")
                            .foregroundStyle(.secondary)
                    }
                } else if let estimate = costEstimate {
                    VStack(alignment: .leading, spacing: 12) {
                        // Cost
                        HStack {
                            Label("Estimated Cost", systemImage: "dollarsign.circle")
                                .font(.subheadline)
                            Spacer()
                            Text(estimate.formattedCost)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        // Time
                        HStack {
                            Label("Generation Time", systemImage: "clock")
                                .font(.subheadline)
                            Spacer()
                            Text(estimate.formattedTime)
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        // Recommendations
                        if !estimate.recommendations.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recommendations")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                ForEach(estimate.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(recommendation.hasPrefix("💡") ? "💡" : "⚠️")
                                        Text(recommendation.trimmingCharacters(in: CharacterSet(charactersIn: "💡⚠️ ")))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Button("Calculate Cost") {
                        fetchCostEstimate()
                    }
                }
            } header: {
                Text("Cost Estimate")
            }
            
            // Presets
            Section("Quick Presets") {
                Button {
                    options = .recommended
                    fetchCostEstimate()
                } label: {
                    Label("Recommended (Balanced)", systemImage: "star.fill")
                }
                
                Button {
                    options = .economical
                    fetchCostEstimate()
                } label: {
                    Label("Economical (Fast)", systemImage: "bolt.fill")
                }
                
                Button {
                    options = .premium
                    fetchCostEstimate()
                } label: {
                    Label("Premium (Ultra Quality)", systemImage: "sparkles")
                }
            }
        }
        .navigationTitle("Generation Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Generate") {
                    onGenerate(options)
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            fetchCostEstimate()
        }
    }
    
    // MARK: - Helpers
    
    private func fetchCostEstimate() {
        isLoadingEstimate = true
        
        Task {
            do {
                let estimate = try await BackendAIService.shared.estimateCost(
                    topic: topic,
                    options: options
                )
                await MainActor.run {
                    costEstimate = estimate
                    isLoadingEstimate = false
                }
            } catch {
                Log.course.error("Failed to estimate cost: \(error)")
                await MainActor.run {
                    isLoadingEstimate = false
                }
            }
        }
    }
    
    private func tierColor(_ tier: QualityTier) -> Color {
        switch tier {
        case .ultra: return .purple
        case .balanced: return .blue
        case .fast: return .green
        case .custom: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CourseGenerationSettingsView(
            options: .constant(.recommended),
            topic: "Python Programming for Beginners"
        ) { options in
            Log.course.info("Generate with options: \(String(describing: options))")
        }
    }
}
