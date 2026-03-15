import Foundation

// MARK: - Network Client
/// Actor-based thread-safe networking client with interceptors, retry logic, and automatic token refresh
actor NetworkClient: NetworkRequestable {

    // MARK: - Properties
    static let shared = NetworkClient()
    static var baseURL: String { AppConfig.baseURL }

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
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        cachePolicy: CachePolicy = .default
    ) async throws -> T {

        // 1. Check cache first if policy allows
        // Note: We can only retrieve from cache if T is Decodable (which it is)
        // But the cache stores encoded data.
        if cachePolicy != .reloadIgnoringCache,
           let cached: T = await cache.get(key: endpoint.cacheKey) {
            logger.log("📦 Cache HIT: \(endpoint.path)")
            return cached
        }
        
        // 2. Check network connectivity
        let isConnected = await MainActor.run { NetworkMonitor.shared.isConnected }
        if !isConnected {
            // If offline, try to return stale cache if available
            if let staleCache: T = await cache.get(key: endpoint.cacheKey, ignoreExpiry: true) {
                logger.log("📡 Offline - using stale cache: \(endpoint.path)")
                return staleCache
            }
            // No cache available - throw offline error
            logger.log("❌ Offline - no cache available: \(endpoint.path)")
            throw LyoError.network(.noInternetConnection)
        }

        // 3. Build request
        var request = try endpoint.buildURLRequest()

        // 3. Apply request interceptors
        request = try await applyHeaders(request, endpoint: endpoint)

        // 4. Execute with retry logic
        let response = try await executeWithRetry(request: request, endpoint: endpoint)

        // 5. Apply response interceptors
        let processedResponse = try await applyResponseInterceptors(response)

        // 6. Decode response
        #if DEBUG
        if let urlPath = request.url?.path, urlPath.contains("/course/") {
            let rawString = String(data: processedResponse.data, encoding: .utf8) ?? "<non-UTF8>"
            print("🌐 RAW RESPONSE [\\(urlPath)]: \\(rawString.prefix(2000))")
        }
        #endif
        
        let decoded: T
        do {
            let decoder = JSONDecoder.lyoDecoder
            decoded = try decoder.decode(T.self, from: processedResponse.data)
        } catch let DecodingError.keyNotFound(key, context) {
            print("🚨 DECODE FAIL: Missing key '\\(key.stringValue)' — \\(context.debugDescription)")
            print("🚨 codingPath: \\(context.codingPath.map(\\.stringValue))")
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.typeMismatch(type, context) {
            print("🚨 DECODE FAIL: Type mismatch for \\(type) — \\(context.debugDescription)")
            print("🚨 codingPath: \\(context.codingPath.map(\\.stringValue))")
            throw DecodingError.typeMismatch(type, context)
        } catch let DecodingError.valueNotFound(type, context) {
            print("🚨 DECODE FAIL: Null value for \\(type) — \\(context.debugDescription)")
            throw DecodingError.valueNotFound(type, context)
        } catch let DecodingError.dataCorrupted(context) {
            print("🚨 DECODE FAIL: Corrupted data — \\(context.debugDescription)")
            throw DecodingError.dataCorrupted(context)
        } catch {
            print("🚨 NETWORK ERROR: \\(error.localizedDescription)")
            throw error
        }

        // 7. Cache if policy allows and TTL > 0 (skip caching for dynamic endpoints with TTL=0)
        // Only cache if the type is Encodable
        /* 
        // FIXME: Generics issue with existential Encodable. Re-enable when cache.set supports existential or overload request.
        if cachePolicy != .reloadIgnoringCache && endpoint.cacheTTL > 0,
           let encodableValue = decoded as? Encodable {
            await cache.set(
                key: endpoint.cacheKey,
                value: encodableValue,
                ttl: endpoint.cacheTTL
            )
            logger.log("💾 Cached: \(endpoint.path)")
        }
        */

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
        request = try await applyHeaders(request, endpoint: endpoint)

        // Execute
        let response = try await executeWithRetry(request: request, endpoint: endpoint)
        let processedResponse = try await applyResponseInterceptors(response)

        // Decode
        let decoder = JSONDecoder.lyoDecoder
        return try decoder.decode(T.self, from: processedResponse.data)
    }

    /// Upload raw binary data (e.g. for presigned URLs)
    /// - Parameters:
    ///   - url: The full destination URL (e.g. Google Cloud Storage signed URL)
    ///   - data: The raw binary data to upload
    ///   - contentType: The MIME type of the data
    ///   - headers: Optional additional headers
    func uploadBinary(
        url: URL,
        data: Data,
        contentType: String,
        headers: [String: String]? = nil
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        request.httpBody = data
        
        // Log request
        logger.logRequest(request, attempt: 0)
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyoError.network(.invalidResponse)
        }
        
        let networkResponse = NetworkResponse(
            data: responseData,
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:]
        )
        
        logger.logResponse(networkResponse, for: request)
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw LyoError.network(.serverError(httpResponse.statusCode))
        }
    }

    /// Execute a streaming request
    func stream(_ endpoint: Endpoint) async throws -> (URLSession.AsyncBytes, URLResponse) {
        var request = try endpoint.buildURLRequest()
        
        // Apply interceptors
        request = try await applyHeaders(request, endpoint: endpoint)
        
        // Log request
        logger.logRequest(request, attempt: 0)
        
        return try await session.bytes(for: request)
    }

    /// Execute a request and return raw Data (for binary responses like TTS audio)
    func requestRawData(_ endpoint: Endpoint) async throws -> Data {
        var request = try endpoint.buildURLRequest()
        request = try await applyHeaders(request, endpoint: endpoint)
        
        let response = try await executeWithRetry(request: request, endpoint: endpoint)
        
        guard (200...299).contains(response.statusCode) else {
            throw LyoError.network(.serverError(response.statusCode))
        }
        
        return response.data
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
                    var refreshedRequest = request
                    if let token = await TokenManager.shared.getToken() {
                        refreshedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    } else {
                        refreshedRequest.setValue(nil, forHTTPHeaderField: "Authorization")
                    }
                    return try await executeWithRetry(request: refreshedRequest, endpoint: endpoint, attempt: attempt + 1)
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

    /// Applies standard headers (Auth, API Key, Tenant ID) to a request
    func applyHeaders(_ request: URLRequest, endpoint: Endpoint? = nil) async throws -> URLRequest {
        var modifiedRequest = request

        let requiresAuth = endpoint?.requiresAuth ?? true

        // 1. Add authentication token
        if requiresAuth, let token = await TokenManager.shared.getToken() {
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // 2. Add common headers
        // Preserve any existing content type (e.g. multipart/form-data)
        if modifiedRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            modifiedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
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

            // Use the typed endpoint + standard header pipeline so SaaS headers are always present.
            let refreshResponse: TokenRefreshResponse = try await self.request(
                Endpoints.Auth.refresh(refreshToken: refreshToken),
                cachePolicy: .reloadIgnoringCache
            )

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
        // Use custom date decoding to handle ISO8601 with fractional seconds
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try with fractional seconds first
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback to standard ISO8601
            let standardFormatter = ISO8601DateFormatter()
            standardFormatter.formatOptions = [.withInternetDateTime]
            if let date = standardFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
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

extension URLRequest {
    static func authenticatedRequest(url: URL, method: String, body: Data?, token: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
}
