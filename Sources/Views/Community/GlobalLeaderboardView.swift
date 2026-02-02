//
//  GlobalLeaderboardView.swift
//  Lyo
//
//  A premium, glassmorphic leaderboard to foster community competition.
//

import SwiftUI

struct GlobalLeaderboardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var stackService: StackService
    
    @State private var selectedType: LeaderboardType = .xp
    @State private var entries: [LeaderboardEntry] = []
    @State private var myRank: LeaderboardRank?
    @State private var isLoading = true
    
    enum LeaderboardType: String, CaseIterable {
        case xp = "XP"
        case streak = "Streak"
        case contribution = "Impact"
        
        var icon: String {
            switch self {
            case .xp: return "bolt.fill"
            case .streak: return "flame.fill"
            case .contribution: return "star.fill"
            }
        }
        
        var apiKey: String {
            switch self {
            case .xp: return "xp"
            case .streak: return "streak"
            case .contribution: return "contribution"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [DesignSystem.Colors.fallbackBackground, DesignSystem.Colors.fallbackSecondary.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Type Selector
                typeSelector
                    .padding(.vertical, 20)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // My Rank Card
                            if let rank = myRank {
                                MyRankCard(rank: rank)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                            }
                            
                            // Top 3 (Special UI)
                            if entries.count >= 3 {
                                TopThreeView(entries: Array(entries.prefix(3)))
                                    .padding(.vertical, 10)
                            }
                            
                            // Remainder of List
                            VStack(spacing: 8) {
                                ForEach(entries.dropFirst(3)) { entry in
                                    LeaderboardRow(entry: entry)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchData()
        }
        .onChange(of: selectedType) { _, _ in
            fetchData()
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Hall of Fame")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for alignment
            Circle().fill(Color.clear).frame(width: 44)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var typeSelector: some View {
        HStack(spacing: 12) {
            ForEach(LeaderboardType.allCases, id: \.self) { type in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedType = type
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: type.icon)
                        Text(type.rawValue)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(selectedType == type ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedType == type ? 
                                  AnyShapeStyle(LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")], startPoint: .leading, endPoint: .trailing)) :
                                  AnyShapeStyle(.ultraThinMaterial))
                    )
                }
            }
        }
    }
    
    private func fetchData() {
        isLoading = true
        Task {
            do {
                self.entries = try await LyoRepository.shared.getLeaderboard(type: selectedType.apiKey)
                self.myRank = try await LyoRepository.shared.getMyLeaderboardRank(type: selectedType.apiKey)
                self.isLoading = false
            } catch {
                print("❌ Leaderboard fetch error: \(error)")
                // Mock data fallback for preview/demo
                generateMockData()
                self.isLoading = false
            }
        }
    }
    
    private func generateMockData() {
        self.entries = (1...10).map { i in
            LeaderboardEntry(
                id: "\(i)",
                rank: i,
                userId: "user_\(i)",
                userName: ["Alex", "Jordan", "Sam", "Skyler", "Taylor", "Morgan", "Robin", "Casey", "Drew", "Jamie"][i-1],
                avatarURL: nil,
                xp: 5000 - (i * 300),
                level: 20 - i,
                badge: i == 1 ? "Top Learner" : nil
            )
        }
        self.myRank = LeaderboardRank(rank: 42, totalUsers: 1540, percentile: 97.2, xp: 1250)
    }
}

// MARK: - Subviews

struct MyRankCard: View {
    let rank: LeaderboardRank
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR STANDING")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("#\(rank.rank)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text("of \(rank.totalUsers)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("PERCENTILE")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.6))
                Text("\(String(format: "%.1f", rank.percentile))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "10B981"))
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}

struct TopThreeView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // #2
            PodiumView(entry: entries[1], height: 140, rank: 2, color: Color(hex: "94A3B8"))
            
            // #1
            PodiumView(entry: entries[0], height: 180, rank: 1, color: Color(hex: "FBBF24"))
                .zIndex(1)
            
            // #3
            PodiumView(entry: entries[2], height: 120, rank: 3, color: Color(hex: "B45309"))
        }
        .padding(.horizontal)
    }
}

struct PodiumView: View {
    let entry: LeaderboardEntry
    let height: CGFloat
    let rank: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: rank == 1 ? 80 : 64)
                    .overlay(Circle().stroke(color, lineWidth: 2))
                
                Image(systemName: "person.fill")
                    .font(.system(size: rank == 1 ? 40 : 32))
                    .foregroundColor(.white)
                
                // Rank Badge
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(6)
                    .background(color)
                    .clipShape(Circle())
                    .offset(y: rank == 1 ? 35 : 28)
            }
            
            Text(entry.userName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            // Podium
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: height)
                .overlay(
                    VStack {
                        Spacer()
                        Text("\(entry.xp)")
                            .font(.system(size: 16, weight: .black))
                        Text("XP")
                            .font(.caption2.bold())
                            .opacity(0.6)
                    }
                    .padding(.bottom, 20)
                )
        }
    }
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(entry.rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 30)
            
            Circle()
                .fill(.white.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.4)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.userName)
                    .font(.system(size: 16, weight: .bold))
                
                if let badge = entry.badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.xp)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text("XP")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
