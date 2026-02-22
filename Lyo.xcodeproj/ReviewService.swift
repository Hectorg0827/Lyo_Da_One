import Foundation

// MARK: - Review Service
/// A small service wrapper around Endpoints.Community review endpoints
final class ReviewService {
    static let shared = ReviewService()
    private let network = NetworkClient.shared
    private init() {}

    // Fetch list of reviews. Backend may return either a bare array or a wrapped object.
    func fetchReviews(targetType: String, targetId: String) async throws -> [APIReview] {
        let endpoint = Endpoints.Community.getReviews(targetType: targetType, targetId: targetId)
        do {
            return try await requestDecoding(endpoint)
        } catch {
            // Try wrapped format: { "reviews": [...] }
            struct Wrapper: Decodable { let reviews: [APIReview] }
            let wrapped: Wrapper = try await requestDecoding(endpoint)
            return wrapped.reviews
        }
    }

    // Fetch review stats. Backend may return either a bare object or wrapped.
    func fetchReviewStats(targetType: String, targetId: String) async throws -> APIReviewStats {
        let endpoint = Endpoints.Community.getReviewStats(targetType: targetType, targetId: targetId)
        do {
            return try await requestDecoding(endpoint)
        } catch {
            // Try wrapped format: { "stats": { ... } }
            struct Wrapper: Decodable { let stats: APIReviewStats }
            let wrapped: Wrapper = try await requestDecoding(endpoint)
            return wrapped.stats
        }
    }

    // Submit a review
    func submitReview(targetType: String, targetId: String, rating: Int, text: String) async throws -> APIReview {
        let request = APIReviewRequest(targetId: targetId, targetType: targetType, rating: rating, text: text)
        let endpoint = Endpoints.Community.submitReview(request: request)
        return try await requestDecoding(endpoint)
    }

    // MARK: - Helpers

    private func requestDecoding<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await network.request(endpoint)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}

