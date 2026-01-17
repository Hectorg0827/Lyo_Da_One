import Foundation

protocol NetworkRequestable {
    func request<T: Codable>(
        _ endpoint: Endpoint,
        cachePolicy: CachePolicy
    ) async throws -> T
}

extension NetworkRequestable {
    func request<T: Codable>(
        _ endpoint: Endpoint,
        cachePolicy: CachePolicy = .default
    ) async throws -> T {
        return try await request(endpoint, cachePolicy: cachePolicy)
    }
}
