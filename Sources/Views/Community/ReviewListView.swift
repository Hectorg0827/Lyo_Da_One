//
//  ReviewListView.swift
//  Lyo
//
//  View for displaying a list of reviews and rating stats
//

import SwiftUI

@MainActor
class ReviewsViewModel: ObservableObject {
    @Published var reviews: [APIReview] = []
    @Published var stats: APIReviewStats?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let targetType: String
    private let targetId: String
    private let service = ReviewService.shared
    
    init(targetType: String, targetId: String) {
        self.targetType = targetType
        self.targetId = targetId
    }
    
    func fetchReviews() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let fetchedReviews = try await service.fetchReviews(targetType: targetType, targetId: targetId)
                let fetchedStats = try await service.fetchReviewStats(targetType: targetType, targetId: targetId)
                
                await MainActor.run {
                    self.reviews = fetchedReviews
                    self.stats = fetchedStats
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

struct ReviewListView: View {
    @StateObject private var viewModel: ReviewsViewModel
    @State private var showAll = false
    
    // Limits the list initially
    private let initialLimit = 3
    
    init(targetType: String, targetId: String) {
        _viewModel = StateObject(wrappedValue: ReviewsViewModel(targetType: targetType, targetId: targetId))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else {
                // Stats Header
                if let stats = viewModel.stats {
                    HStack(spacing: 20) {
                        VStack {
                            Text(String(format: "%.1f", stats.averageRating))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("out of 5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(stats.reviewCount) Ratings")
                                .font(.headline)
                            
                            // Star bars would go here in a more advanced version
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(stats.averageRating.rounded()) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Reviews
                VStack(spacing: 16) {
                    ForEach(displayedReviews) { review in
                        ReviewRow(review: review)
                    }
                    
                    if viewModel.reviews.count > initialLimit && !showAll {
                        Button("See All Reviews") {
                            withAnimation {
                                showAll = true
                            }
                        }
                        .font(.subheadline.bold())
                        .padding(.top, 8)
                    }
                    
                    if viewModel.reviews.isEmpty {
                        Text("No reviews yet. Be the first!")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchReviews()
        }
    }
    
    private var displayedReviews: [APIReview] {
        if showAll {
            return viewModel.reviews
        } else {
            return Array(viewModel.reviews.prefix(initialLimit))
        }
    }
}

struct ReviewRow: View {
    let review: APIReview
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Group {
                        if let avatar = review.author.avatar, let url = URL(string: avatar) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }
                            }
                        } else {
                            Text(review.author.name.prefix(1))
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }
                )
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(review.author.name)
                        .font(.subheadline.bold())
                    
                    Spacer()
                    
                    Text(review.timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(review.text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
