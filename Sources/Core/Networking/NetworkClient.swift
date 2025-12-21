import Foundation

// MARK: - Network Client
/// Actor-based thread-safe networking client with interceptors, retry logic, and automatic token refresh
actor NetworkClient {

    // MARK: - Properties
    static let shared = NetworkClient()

    private let session: URLSession
    private var tokenRefreshTask: Task<String, Error>?
    private let cache: NetworkCache
    private let logger: NetworkLogger

    // MARK: - Configuration
    private let maxRetries = 3
    private let timeoutInterval: TimeInterval = 60  // Increased for slow backend

    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil // We'll handle caching manually

        self.session = URLSession(configuration: config)
        self.cache = NetworkCache.shared
        self.logger = NetworkLogger()
    }

    // MARK: - Public API

    /// Execute a network request with automatic retry and caching
    func request<T: Codable>(
        _ endpoint: Endpoint,
        cachePolicy: CachePolicy = .default
    ) async throws -> T {

        // 1. Check cache first if policy allows
        if cachePolicy != .reloadIgnoringCache,
           let cached: T = await cache.get(key: endpoint.cacheKey) {
            logger.log("📦 Cache HIT: \(endpoint.path)")
            return cached
        }

        // 2. Build request
        var request = try endpoint.buildURLRequest()

        // 3. Apply request interceptors
        request = try await applyRequestInterceptors(request)

        // 4. Execute with retry logic
        let response = try await executeWithRetry(request: request, endpoint: endpoint)

        // 5. Apply response interceptors
        let processedResponse = try await applyResponseInterceptors(response)

        // 6. Decode response
        let decoder = JSONDecoder.lyoDecoder
        let decoded: T = try decoder.decode(T.self, from: processedResponse.data)

        // 7. Cache if policy allows
        if cachePolicy != .reloadIgnoringCache {
            await cache.set(
                key: endpoint.cacheKey,
                value: decoded,
                ttl: endpoint.cacheTTL
            )
            logger.log("💾 Cached: \(endpoint.path)")
        }

        return decoded
    }

    /// Upload multipart form data
    func upload<T: Decodable>(
        _ endpoint: Endpoint,
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T {

        var request = try endpoint.buildURLRequest()

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Apply interceptors
        request = try await applyRequestInterceptors(request)

        // Execute
        let response = try await executeWithRetry(request: request, endpoint: endpoint)
        let processedResponse = try await applyResponseInterceptors(response)

        // Decode
        let decoder = JSONDecoder.lyoDecoder
        return try decoder.decode(T.self, from: processedResponse.data)
    }

    // MARK: - Request Execution

    private func executeWithRetry(
        request: URLRequest,
        endpoint: Endpoint? = nil,
        attempt: Int = 0
    ) async throws -> NetworkResponse {

        logger.logRequest(request, attempt: attempt)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LyoError.network(.invalidResponse)
            }

            let networkResponse = NetworkResponse(
                data: data,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
            )

            logger.logResponse(networkResponse, for: request)

            // Check if response is successful
            if (200...299).contains(httpResponse.statusCode) {
                return networkResponse
            }

            // Handle specific error status codes
            switch httpResponse.statusCode {
            case 401:
                // Only attempt token refresh if endpoint requires auth
                // Don't refresh for login/register endpoints
                if attempt == 0 && endpoint?.requiresAuth != false {
                    try await refreshTokenIfNeeded()
                    return try await executeWithRetry(request: request, endpoint: endpoint, attempt: attempt + 1)
                }
                throw LyoError.network(.unauthorized)

            case 429:
                // Handle rate limiting
                var retryAfter: TimeInterval?
                if let retryHeader = httpResponse.allHeaderFields["Retry-After"] as? String,
                   let seconds = Double(retryHeader) {
                    retryAfter = seconds
                }
                throw LyoError.rateLimitExceeded(retryAfter: retryAfter)

            case 400:
                // Parse validation errors
                if let validationError = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                    throw LyoError.validation(validationError)
                }
                throw LyoError.network(.badRequest)

            case 404:
                throw LyoError.network(.notFound)

            case 500...599:
                throw LyoError.network(.serverError(httpResponse.statusCode))

            default:
                throw LyoError.network(.unknown(httpResponse.statusCode))
            }

        } catch let error as LyoError {
            // Don't retry on specific errors
            if case .network(.unauthorized) = error {
                throw error
            }
            if case .network(.badRequest) = error {
                throw error
            }
            if case .validation = error {
                throw error
            }

            // Retry on network errors
            if attempt < maxRetries && shouldRetry(error: error) {
                let delay = calculateBackoff(attempt: attempt)
                logger.log("🔄 Retry attempt \(attempt + 1)/\(maxRetries) after \(delay)s")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(request: request, attempt: attempt + 1)
            }

            throw error

        } catch {
            // Network-level errors (no internet, timeout, etc.)
            if attempt < maxRetries {
                let delay = calculateBackoff(attempt: attempt)
                logger.log("🔄 Network error, retry \(attempt + 1)/\(maxRetries) after \(delay)s")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(request: request, attempt: attempt + 1)
            }

            throw LyoError.network(.connectionFailed(error.localizedDescription))
        }
    }

    // MARK: - Interceptors

    private func applyRequestInterceptors(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        // 1. Add authentication token
        if let token = await TokenManager.shared.getToken() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 2. Add common headers
        modifiedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        modifiedRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        modifiedRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
        modifiedRequest.setValue(AppConfig.version, forHTTPHeaderField: "X-App-Version")

        // 3. Add tenant ID if available
        if let tenantId = await TokenManager.shared.getTenantId() {
            modifiedRequest.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
        }
        
        // 4. Add API Key (SaaS Auth)
        modifiedRequest.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")

        return modifiedRequest
    }

    private func applyResponseInterceptors(_ response: NetworkResponse) async throws -> NetworkResponse {
        // Response interceptors can modify response data if needed
        // For now, just return as-is
        return response
    }

    // MARK: - Token Management

    private func refreshTokenIfNeeded() async throws {
        // Prevent multiple simultaneous refresh requests
        if let existingTask = tokenRefreshTask {
            _ = try await existingTask.value
            return
        }

        let task = Task<String, Error> {
            logger.log("🔄 Refreshing authentication token...")

            guard let refreshToken = await TokenManager.shared.getRefreshToken() else {
                logger.log("❌ Refresh failed: No refresh token stored")
                throw LyoError.network(.unauthorized)
            }

            // Build refresh request
            var request = URLRequest(url: URL(string: "\(AppConfig.baseURL)/auth/refresh")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["refresh_token": refreshToken]
            request.httpBody = try JSONEncoder().encode(body)

            // Execute without retry (to avoid infinite loop)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                logger.log("❌ Refresh failed with status: \(status)")
                if let responseString = String(data: data, encoding: .utf8) {
                    logger.log("❌ Refresh response: \(responseString)")
                }
                throw LyoError.network(.unauthorized)
            }

            let refreshResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

            // Store new tokens
            await TokenManager.shared.setToken(refreshResponse.accessToken)
            if let newRefreshToken = refreshResponse.refreshToken {
                await TokenManager.shared.setRefreshToken(newRefreshToken)
            }

            logger.log("✅ Token refreshed successfully")

            return refreshResponse.accessToken
        }

        tokenRefreshTask = task

        do {
            _ = try await task.value
            tokenRefreshTask = nil
        } catch {
            tokenRefreshTask = nil
            throw error
        }
    }

    // MARK: - Helper Methods

    private func shouldRetry(error: Error) -> Bool {
        // Retry on network errors, timeouts, and 5xx server errors
        if case LyoError.network(.serverError) = error {
            return true
        }
        if case LyoError.network(.connectionFailed) = error {
            return true
        }
        return false
    }

    private func calculateBackoff(attempt: Int) -> Double {
        // Exponential backoff: 1s, 2s, 4s
        return pow(2.0, Double(attempt))
    }
}

// MARK: - Supporting Types

struct NetworkResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct ValidationErrorResponse: Codable {
    let detail: [ValidationError]

    struct ValidationError: Codable {
        let loc: [String]
        let msg: String
        let type: String
    }
}

// MARK: - JSONDecoder Extension

extension JSONDecoder {
    static var lyoDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

// MARK: - JSONEncoder Extension

extension JSONEncoder {
    static var lyoEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}
