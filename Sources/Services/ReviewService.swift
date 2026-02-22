import Foundation

@MainActor
class ReviewService: ObservableObject {
    static let shared = ReviewService()
    private let client: NetworkClient
    
    private init(client: NetworkClient = .shared) {
        self.client = client
    }
    
    func fetchReviews(targetType: String, targetId: String) async throws -> [APIReview] {
        let response: APIReviewListResponse = try await client.request(
            Endpoints.Community.getReviews(targetType: targetType, targetId: targetId)
        )
        return response.reviews
    }
    
    func fetchReviewStats(targetType: String, targetId: String) async throws -> APIReviewStats {
        return try await client.request(
            Endpoints.Community.getReviewStats(targetType: targetType, targetId: targetId)
        )
    }
    
    func submitReview(targetType: String, targetId: String, rating: Int, text: String) async throws -> APIReview {
        let request = APIReviewRequest(
            targetId: targetId,
            targetType: targetType,
            rating: rating,
            text: text
        )
        return try await client.request(Endpoints.Community.submitReview(request: request))
    }
}

struct APIReviewListResponse: Codable {
    let reviews: [APIReview]
    let total: Int?
}
