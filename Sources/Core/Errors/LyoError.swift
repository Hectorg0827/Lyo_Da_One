import Foundation

// MARK: - Lyo Error
/// Comprehensive error handling for the Lyo app
enum LyoError: Error, Identifiable {
    case network(NetworkErrorType)
    case validation(ValidationErrorResponse)
    case business(BusinessErrorType)
    case ai(AIErrorType)
    case storage(StorageErrorType)
    case serverError(String)
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case unknown(String)
    case speechRecognitionError
    case offlineMode
    
    var id: String {
        switch self {
        case .network: return "network_error"
        case .validation: return "validation_error"
        case .business: return "business_error"
        case .ai: return "ai_error"
        case .storage: return "storage_error"
        case .serverError: return "server_error"
        case .rateLimitExceeded: return "rate_limited"
        case .unknown: return "unknown_error"
        case .speechRecognitionError: return "speech_error"
        case .offlineMode: return "offline_mode"
        }
    }
}


// MARK: - Network Error Types
enum NetworkErrorType {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case unauthorized
    case forbidden
    case badRequest
    case notFound
    case methodNotAllowed
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
    case processingError(String)
    case courseGenerationFailed(String)
    case quizGenerationFailed(String)
}

enum LyoEmotion: String, Codable {
    case friendly, excited, thoughtful, encouraging, apologetic, confused, proud
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
        case .speechRecognitionError:
            return "Speech recognition failed"
        case .offlineMode:
            return "Device is offline"
        }
    }

    var lyoMessage: String {
        switch self {
        case .network(.unauthorized):
            return "I need you to sign in first so I can personalize your learning!"
        case .network:
            return "Oops! I can't reach my brain in the cloud right now."
        case .ai(.processingError):
            return "I'm having trouble understanding. Let me try that again!"
        case .ai(.courseGenerationFailed):
            return "I ran into trouble creating your course. Let's try a different approach!"
        case .ai(.quizGenerationFailed):
            return "I couldn't generate that quiz right now. How about we review the topic instead?"
        case .business(.userNotFound):
            return "I couldn't find your profile. Let's explore together!"
        case .rateLimitExceeded:
            return "Whoa there! I need a moment to catch my breath."
        case .offlineMode:
            return "I'm in offline mode, but I can still help with what I know!"
        case .speechRecognitionError:
            return "I couldn't quite catch that. Could you try speaking again?"
        default:
            return "Something unexpected happened, but don't worry - I'm here to help!"
        }
    }

    var actionableAdvice: String {
        switch self {
        case .network(.unauthorized):
            return "Signing in unlocks personalized courses and progress tracking."
        case .network:
            return "Check your internet connection, or I can work with cached content."
        case .ai(.processingError):
            return "Try rephrasing your question, or I can suggest some alternatives."
        case .business(.userNotFound):
            return "I can create new content for you, or suggest similar topics."
        case .rateLimitExceeded(let retryAfter):
            let minutes = Int((retryAfter ?? 60) / 60)
            return "Try again in \(minutes) minute\(minutes == 1 ? "" : "s"), or explore existing content."
        case .offlineMode:
            return "I'll sync everything when you're back online!"
        case .speechRecognitionError:
            return "Make sure your microphone is enabled and try speaking clearly."
        case .ai(.courseGenerationFailed), .ai(.quizGenerationFailed):
            return "Let's break down your topic into smaller pieces I can handle."
        default:
            return "Let's start fresh - what would you like to learn about?"
        }
    }

    var emotion: LyoEmotion {
        switch self {
        case .network(.unauthorized):
            return .encouraging
        case .network, .unknown, .serverError:
            return .apologetic
        case .ai(.processingError):
            return .confused
        case .business(.userNotFound):
            return .thoughtful
        case .rateLimitExceeded:
            return .apologetic
        case .offlineMode:
            return .friendly
        case .speechRecognitionError:
            return .confused
        case .ai(.courseGenerationFailed), .ai(.quizGenerationFailed):
            return .apologetic
        default:
            return .apologetic
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

    var suggestedActions: [LyoAction] {
        switch self {
        case .network(.unauthorized):
            return [
                LyoAction(id: "sign_in", title: "Sign In", icon: "person.circle", style: .primary, handler: {})
            ]
        case .network:
            return [
                LyoAction(id: "retry", title: "Try Again", icon: "arrow.clockwise", style: .primary, handler: {})
            ]
        case .ai(.processingError):
            return [
                LyoAction(id: "rephrase", title: "Help Me Rephrase", icon: "text.bubble", style: .primary, handler: {}),
                LyoAction(id: "try_again", title: "Try Again", icon: "arrow.clockwise", style: .secondary, handler: {})
            ]
        case .speechRecognitionError:
            return [
                LyoAction(id: "try_voice_again", title: "Try Voice Again", icon: "mic", style: .primary, handler: {}),
                LyoAction(id: "type_instead", title: "Type Instead", icon: "keyboard", style: .secondary, handler: {})
            ]
        default:
            return [
                LyoAction(id: "restart", title: "Start Fresh", icon: "arrow.clockwise.circle", style: .primary, handler: {})
            ]
        }
    }
}

// MARK: - Lyo Action
struct LyoAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let style: ActionStyle
    let handler: () -> Void

    enum ActionStyle {
        case primary, secondary, tertiary
    }

    var accessibleLabel: String { title }
    var accessibleHint: String { "Double tap to \(title.lowercased())" }
}


// MARK: - Network Error Description
extension NetworkErrorType {
    var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest:
            return "Invalid request"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .badRequest:
            return "Invalid request"
        case .notFound:
            return "Resource not found"
        case .methodNotAllowed:
            return "Method not allowed"
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
        case .invalidRequest:
            return "The request was invalid."
        case .invalidResponse:
            return "The server returned an unexpected response format."
        case .unauthorized:
            return "Authentication token is missing or invalid."
        case .forbidden:
            return "You do not have permission to access this resource."
        case .badRequest:
            return "The request parameters were invalid."
        case .notFound:
            return "The requested resource was not found on the server."
        case .methodNotAllowed:
            return "The HTTP method is not allowed for this resource."
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
        case .processingError:
            return "AI processing error"
        case .courseGenerationFailed:
            return "Course generation failed"
        case .quizGenerationFailed:
            return "Quiz generation failed"
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
        case .processingError(let details):
            return "AI processing error: \(details)"
        case .courseGenerationFailed(let details):
            return "Course generation failed: \(details)"
        case .quizGenerationFailed(let details):
            return "Quiz generation failed: \(details)"
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
