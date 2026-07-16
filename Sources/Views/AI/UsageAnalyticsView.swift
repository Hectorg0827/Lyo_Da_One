//
//  UsageAnalyticsView.swift
//  Lyo
//
//  Dashboard for viewing course generation usage and costs
//

import SwiftUI
import Charts

struct UsageAnalyticsView: View {
    @State private var analytics: UserAnalytics?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedPeriod: AnalyticsPeriod = .month
    
    enum AnalyticsPeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "90 Days"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedPeriod) { _, _ in
                    Task { await loadAnalytics() }
                }
                
                if isLoading {
                    ProgressView("Loading analytics...")
                        .padding()
                } else if let error = error {
                    ErrorMessageView(message: error)
                } else if let analytics = analytics {
                    analyticsContent(analytics)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Usage Analytics")
        .task {
            await loadAnalytics()
        }
    }
    
    @ViewBuilder
    private func analyticsContent(_ analytics: UserAnalytics) -> some View {
        VStack(spacing: 24) {
            // Summary Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                UsageStatCard(
                    title: "Courses Generated",
                    value: "\(analytics.totalCourses)",
                    subtitle: "\(analytics.completedCourses) completed",
                    icon: "book.fill",
                    color: .blue
                )
                
                UsageStatCard(
                    title: "Total Cost",
                    value: String(format: "$%.2f", analytics.totalCostUSD),
                    subtitle: "Avg: $\(String(format: "%.4f", analytics.avgCostPerCourse))",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                UsageStatCard(
                    title: "Total Tokens",
                    value: formatNumber(analytics.totalTokens),
                    subtitle: "API calls",
                    icon: "cpu.fill",
                    color: .purple
                )
                
                if let qaScore = analytics.avgQAScore {
                    UsageStatCard(
                        title: "Avg Quality",
                        value: "\(Int(qaScore))/100",
                        subtitle: "Quality score",
                        icon: "star.fill",
                        color: .orange
                    )
                }
            }
            .padding(.horizontal)
            
            // Cost Trend Chart
            if !analytics.dailyTrend.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cost Trend")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Chart {
                        ForEach(analytics.dailyTrend, id: \.date) { day in
                            LineMark(
                                x: .value("Date", parseDate(day.date) ?? Date()),
                                y: .value("Cost", day.cost)
                            )
                            .foregroundStyle(.blue)
                            .symbol(.circle)
                            
                            AreaMark(
                                x: .value("Date", parseDate(day.date) ?? Date()),
                                y: .value("Cost", day.cost)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .blue.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            
            // Cost by Tier
            if !analytics.costByTier.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cost by Quality Tier")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(Array(analytics.costByTier.keys.sorted()), id: \.self) { tier in
                        if let tierData = analytics.costByTier[tier] {
                            TierCostRow(
                                tier: tier,
                                count: tierData.count,
                                totalCost: tierData.totalCost,
                                avgCost: tierData.avgCost
                            )
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    
    private func loadAnalytics() async {
        isLoading = true
        error = nil
        
        do {
            // Get actual user ID from auth service
            guard let userId = try await AuthService.shared.getCurrentUserId() else {
                throw NSError(
                    domain: "UsageAnalytics",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Please log in to view analytics"]
                )
            }
            
            // Use correct backend endpoint format
            let endpointPath = "/api/v2/courses/analytics?user_id=\(userId)&days=\(selectedPeriod.days)"
            
            let dynamicEndpoint = DynamicEndpoint(
                urlString: endpointPath,
                method: .get,
                requiresAuth: true
            )
            
            analytics = try await NetworkClient.shared.request(dynamicEndpoint)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Usage Stat Card

struct UsageStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tier Cost Row

struct TierCostRow: View {
    let tier: String
    let count: Int
    let totalCost: Double
    let avgCost: Double
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tier.capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(count) courses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.4f", totalCost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Avg: $\(String(format: "%.4f", avgCost))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Error View

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Models

struct UserAnalytics: Codable {
    let periodDays: Int
    let totalCourses: Int
    let completedCourses: Int
    let failedCourses: Int
    let totalCostUSD: Double
    let totalTokens: Int
    let avgCostPerCourse: Double
    let avgQAScore: Double?
    let costByTier: [String: TierCostData]
    let dailyTrend: [DailyTrendData]
    
    enum CodingKeys: String, CodingKey {
        case periodDays = "period_days"
        case totalCourses = "total_courses"
        case completedCourses = "completed_courses"
        case failedCourses = "failed_courses"
        case totalCostUSD = "total_cost_usd"
        case totalTokens = "total_tokens"
        case avgCostPerCourse = "avg_cost_per_course"
        case avgQAScore = "avg_qa_score"
        case costByTier = "cost_by_tier"
        case dailyTrend = "daily_trend"
    }
}

struct TierCostData: Codable {
    let count: Int
    let totalCost: Double
    let avgCost: Double
    
    enum CodingKeys: String, CodingKey {
        case count
        case totalCost = "total_cost"
        case avgCost = "avg_cost"
    }
}

struct DailyTrendData: Codable {
    let date: String
    let cost: Double
    let courses: Int
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UsageAnalyticsView()
    }
}
