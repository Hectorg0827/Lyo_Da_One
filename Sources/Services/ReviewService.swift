import Foundation

@MainActor
class ReviewService: ObservableObject {
    static let shared = ReviewService()
    private let client: NetworkClient
    
    private init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func fetchReviews(targetType: String, targetId: String) async throws -> [APIReview] {
        []
    }
    
    func fetchReviewStats(targetType: String, targetId: String) async throws -> APIReviewStats {
        APIReviewStats(averageRating: 0, reviewCount: 0)
    }
    
    func submitReview(targetType: String, targetId: String, rating: Int, text: String) async throws -> APIReview {
        APIReview(
            id: UUID().uuidString,
            author: APIUserPreview(id: 0, name: "You", avatar: nil),
            rating: rating,
            text: text,
            timestamp: Date()
        )
    }
}

struct APIReviewListResponse: Codable {
    let reviews: [APIReview]
    let total: Int?
}
