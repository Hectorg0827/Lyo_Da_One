import Foundation

// MARK: - Lyo Error
/// Comprehensive error handling for the Lyo app
enum LyoError: Error {
    case network(NetworkErrorType)
    case validation(ValidationErrorResponse)
    case business(BusinessErrorType)
    case ai(AIErrorType)
    case storage(StorageErrorType)
    case serverError(String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case unknown(String)
}

// MARK: - Network Error Types
enum NetworkErrorType {
    case invalidURL
    case invalidResponse
    case unauthorized
    case badRequest
    case notFound
    case serverError(Int)
    case connectionFailed(String)
    case timeout
    case noInternetConnection
    case notImplemented
    case unknown(Int)
}

// MARK: - Business Error Types
enum BusinessErrorType {
    case courseNotFound
    case lessonNotFound
    case userNotFound
    case insufficientCredits
    case featureNotAvailable
    case invalidOperation(String)
}

// MARK: - AI Error Types
enum AIErrorType {
    case generationFailed
    case quotaExceeded
    case invalidPrompt
    case contentFiltered
    case modelUnavailable
}

// MARK: - Storage Error Types
enum StorageErrorType {
    case cacheFailed
    case persistenceFailed
    case insufficientSpace
    case accessDenied
}

// MARK: - Localized Error
extension LyoError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .network(let type):
            return type.description

        case .validation(let error):
            if let first = error.detail.first {
                return first.msg
            }
            return "Validation failed"

        case .business(let type):
            return type.description

        case .ai(let type):
            return type.description

        case .storage(let type):
            return type.description

        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                return "Too many requests. Please try again in \(Int(delay)) seconds."
            }
            return "Too many requests"

        case .serverError(let message):
            return message

        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network(.noInternetConnection):
            return "Please check your internet connection and try again."

        case .network(.unauthorized):
            return "Please sign in again to continue."

        case .network(.timeout):
            return "The request took too long. Please try again."

        case .network(.serverError):
            return "We're experiencing technical difficulties. Please try again later."

        case .validation:
            return "Please check your input and try again."

        case .business(.insufficientCredits):
            return "Upgrade to Pro to continue learning."

        case .ai(.quotaExceeded):
            return "You've reached your AI usage limit. Upgrade to Pro for unlimited access."

        case .storage(.insufficientSpace):
            return "Please free up some space on your device."

        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                return "Please wait \(Int(delay)) seconds before trying again."
            }
            return "You've made too many requests. Please wait a moment before trying again."

        default:
            return "Please try again. If the problem persists, contact support."
        }
    }

    var failureReason: String? {
        switch self {
        case .network(let type):
            return type.technicalDescription

        case .business(let type):
            return type.technicalDescription

        case .ai(let type):
            return type.technicalDescription

        case .storage(let type):
            return type.technicalDescription

        default:
            return nil
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network(.timeout),
             .network(.connectionFailed),
             .network(.serverError),
             .serverError:
            return true

        case .ai(.modelUnavailable):
            return true

        case .rateLimitExceeded:
            return true

        default:
            return false
        }
    }

    var requiresAuthentication: Bool {
        if case .network(.unauthorized) = self {
            return true
        }
        return false
    }

    var isUserError: Bool {
        switch self {
        case .validation,
             .business(.invalidOperation),
             .network(.badRequest):
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Error Description
extension NetworkErrorType {
    var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Authentication required"
        case .badRequest:
            return "Invalid request"
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error"
        case .connectionFailed:
            return "Connection failed"
        case .timeout:
            return "Request timed out"
        case .noInternetConnection:
            return "No internet connection"
        case .notImplemented:
            return "Feature not implemented"
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }

    var technicalDescription: String {
        switch self {
        case .invalidURL:
            return "The URL provided was malformed or invalid."
        case .invalidResponse:
            return "The server returned an unexpected response format."
        case .unauthorized:
            return "Authentication token is missing or invalid."
        case .badRequest:
            return "The request parameters were invalid."
        case .notFound:
            return "The requested resource was not found on the server."
        case .serverError(let code):
            return "The server encountered an error (HTTP \(code))."
        case .connectionFailed(let reason):
            return "Network connection failed: \(reason)"
        case .timeout:
            return "The request exceeded the timeout limit."
        case .noInternetConnection:
            return "Device is not connected to the internet."
        case .notImplemented:
            return "The requested feature is not yet implemented."
        case .unknown(let code):
            return "An unknown error occurred (HTTP \(code))."
        }
    }
}

// MARK: - Business Error Description
extension BusinessErrorType {
    var description: String {
        switch self {
        case .courseNotFound:
            return "Course not found"
        case .lessonNotFound:
            return "Lesson not found"
        case .userNotFound:
            return "User not found"
        case .insufficientCredits:
            return "Insufficient credits"
        case .featureNotAvailable:
            return "Feature not available"
        case .invalidOperation(let reason):
            return reason
        }
    }

    var technicalDescription: String {
        switch self {
        case .courseNotFound:
            return "The requested course ID does not exist in the database."
        case .lessonNotFound:
            return "The requested lesson ID does not exist in the database."
        case .userNotFound:
            return "The user profile could not be found."
        case .insufficientCredits:
            return "User does not have enough credits to perform this action."
        case .featureNotAvailable:
            return "This feature is not available in the current subscription plan."
        case .invalidOperation(let reason):
            return "Operation cannot be performed: \(reason)"
        }
    }
}

// MARK: - AI Error Description
extension AIErrorType {
    var description: String {
        switch self {
        case .generationFailed:
            return "AI generation failed"
        case .quotaExceeded:
            return "AI usage limit reached"
        case .invalidPrompt:
            return "Invalid prompt"
        case .contentFiltered:
            return "Content filtered"
        case .modelUnavailable:
            return "AI model unavailable"
        }
    }

    var technicalDescription: String {
        switch self {
        case .generationFailed:
            return "The AI model failed to generate a response."
        case .quotaExceeded:
            return "User has exceeded their AI usage quota for this period."
        case .invalidPrompt:
            return "The prompt provided was invalid or contained prohibited content."
        case .contentFiltered:
            return "The generated content was filtered due to safety policies."
        case .modelUnavailable:
            return "The AI model is temporarily unavailable."
        }
    }
}

// MARK: - Storage Error Description
extension StorageErrorType {
    var description: String {
        switch self {
        case .cacheFailed:
            return "Cache operation failed"
        case .persistenceFailed:
            return "Data persistence failed"
        case .insufficientSpace:
            return "Insufficient storage space"
        case .accessDenied:
            return "Storage access denied"
        }
    }

    var technicalDescription: String {
        switch self {
        case .cacheFailed:
            return "Failed to read from or write to cache."
        case .persistenceFailed:
            return "Failed to persist data to disk."
        case .insufficientSpace:
            return "Device does not have enough free space."
        case .accessDenied:
            return "App does not have permission to access storage."
        }
    }
}

// MARK: - Error Conversion
extension LyoError {
    /// Convert URLError to LyoError
    static func from(urlError: URLError) -> LyoError {
        switch urlError.code {
        case .notConnectedToInternet:
            return .network(.noInternetConnection)
        case .timedOut:
            return .network(.timeout)
        case .cannotFindHost, .cannotConnectToHost:
            return .network(.connectionFailed("Cannot reach server"))
        default:
            return .network(.connectionFailed(urlError.localizedDescription))
        }
    }

    /// Convert generic Error to LyoError
    static func from(error: Error) -> LyoError {
        if let lyoError = error as? LyoError {
            return lyoError
        }

        if let urlError = error as? URLError {
            return from(urlError: urlError)
        }

        return .unknown(error.localizedDescription)
    }
}
