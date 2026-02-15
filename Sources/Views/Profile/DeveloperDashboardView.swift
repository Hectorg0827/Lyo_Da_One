
import SwiftUI
import os

struct DeveloperDashboardView: View {
    @StateObject private var viewModel = DeveloperDashboardViewModel()
    @State private var showingCreateKeySheet = false
    @State private var newKeyName = ""
    @State private var createdKey: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let org = viewModel.organization, let usage = viewModel.usage {
                    // Organization Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(org.name)
                                    .font(.title2.bold())
                                Text(org.slug)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            PlanBadge(tier: org.planTier)
                        }
                        
                        Divider()
                        
                        // Limits
                        HStack {
                            Label("\(org.rateLimitPerMinute) req/min", systemImage: "speedometer")
                            Spacer()
                            Label("\(org.monthlyAiTokens) tokens/mo", systemImage: "brain")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Usage Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Usage")
                            .font(.headline)
                        
                        UsageRow(
                            title: "API Calls",
                            current: usage.totalRequests,
                            limit: org.monthlyApiCalls,
                            icon: "server.rack"
                        )
                        
                        UsageRow(
                            title: "AI Tokens",
                            current: usage.totalTokens,
                            limit: org.monthlyAiTokens,
                            icon: "sparkles"
                        )
                        
                        HStack {
                            Text("Estimated Cost")
                            Spacer()
                            Text(String(format: "$%.4f", usage.estimatedCostUsd))
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // API Keys
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("API Keys")
                                .font(.headline)
                            Spacer()
                            Button(action: { showingCreateKeySheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        
                        ForEach(viewModel.apiKeys) { key in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(key.name)
                                        .font(.subheadline.bold())
                                    Text(key.keyPrefix + "...")
                                        .font(.caption.monospaced())
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    Task { await viewModel.revokeKey(id: key.id) }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Failed to load dashboard")
                        Button("Retry") {
                            Task { await viewModel.fetchData() }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Developer Dashboard")
        .task {
            await viewModel.fetchData()
        }
        .sheet(isPresented: $showingCreateKeySheet) {
            NavigationView {
                Form {
                    Section {
                        TextField("Key Name (e.g. Test Key)", text: $newKeyName)
                    }
                    
                    if let key = createdKey {
                        Section(header: Text("Save this key! It won't be shown again.")) {
                            Text(key)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Button("Copy") {
                                UIPasteboard.general.string = key
                            }
                        }
                    }
                }
                .navigationTitle("New API Key")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showingCreateKeySheet = false
                            createdKey = nil
                            newKeyName = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if createdKey == nil {
                            Button("Create") {
                                Task {
                                    if let key = await viewModel.createKey(name: newKeyName) {
                                        createdKey = key
                                    }
                                }
                            }
                            .disabled(newKeyName.isEmpty)
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct PlanBadge: View {
    let tier: String
    
    var color: Color {
        switch tier.lowercased() {
        case "enterprise": return .purple
        case "pro": return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        Text(tier.uppercased())
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct UsageRow: View {
    let title: String
    let current: Int
    let limit: Int
    let icon: String
    
    var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(current) / Double(limit), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline)
                Spacer()
                Text("\(current) / \(limit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                    
                    Capsule()
                        .fill(percentage > 0.9 ? Color.red : Color.blue)
                        .frame(width: geo.size.width * percentage)
                }
            }
            .frame(height: 6)
        }
    }
}

@MainActor
class DeveloperDashboardViewModel: ObservableObject {
    @Published var organization: OrganizationResponse?
    @Published var usage: UsageStatsResponse?
    @Published var apiKeys: [APIKeyInfo] = []
    @Published var isLoading = false
    
    private let service = SaaSService.shared
    
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let orgTask = service.getOrganization()
            async let usageTask = service.getUsageStats()
            async let keysTask = service.listAPIKeys()
            
            let (org, stats, keys) = try await (orgTask, usageTask, keysTask)
            
            self.organization = org
            self.usage = stats
            self.apiKeys = keys
        } catch {
            Log.ui.error("Dashboard load error: \(error)")
        }
    }
    
    func createKey(name: String) async -> String? {
        do {
            let key = try await service.createAPIKey(name: name)
            await fetchData() // Refresh list
            return key
        } catch {
            Log.ui.error("Create key error: \(error)")
            return nil
        }
    }
    
    func revokeKey(id: Int) async {
        do {
            try await service.revokeAPIKey(id: id)
            if let index = apiKeys.firstIndex(where: { $0.id == id }) {
                apiKeys.remove(at: index)
            }
        } catch {
            Log.ui.error("Revoke error: \(error)")
        }
    }
}
