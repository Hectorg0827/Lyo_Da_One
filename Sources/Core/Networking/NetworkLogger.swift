import Foundation
import os

// MARK: - Network Logger
/// Logs all network requests and responses for debugging
struct NetworkLogger {

    // MARK: - Configuration
    private let isEnabled: Bool

    init(enabled: Bool = true) {
        #if DEBUG
        self.isEnabled = enabled
        #else
        self.isEnabled = false
        #endif
    }

    // MARK: - Logging Methods

    func log(_ message: String) {
        guard isEnabled else { return }
        Log.net.info("[Network] \(message)")
    }

    func logRequest(_ request: URLRequest, attempt: Int = 0) {
        guard isEnabled else { return }

        var message = "\n================================\n"
        message += "📤 REQUEST"
        if attempt > 0 {
            message += " (Retry \(attempt))"
        }
        message += "\n================================\n"

        // Method and URL
        if let method = request.httpMethod {
            message += "Method: \(method)\n"
        }
        if let url = request.url?.absoluteString {
            message += "URL: \(url)\n"
        }

        // Headers
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            message += "\nHeaders:\n"
            for (key, value) in headers {
                // Redact sensitive headers
                if key.lowercased().contains("authorization") {
                    message += "  \(key): Bearer ***\n"
                } else {
                    message += "  \(key): \(value)\n"
                }
            }
        }

        // Body
        if let body = request.httpBody {
            message += "\nBody:\n"
            if let jsonObject = try? JSONSerialization.jsonObject(with: body),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                message += prettyString
            } else if let bodyString = String(data: body, encoding: .utf8) {
                message += bodyString
            } else {
                message += "<binary data: \(body.count) bytes>"
            }
        }

        message += "\n================================\n"
        print(message)
    }

    func logResponse(_ response: NetworkResponse, for request: URLRequest) {
        guard isEnabled else { return }

        var message = "\n================================\n"
        message += "📥 RESPONSE\n"
        message += "================================\n"

        // URL
        if let url = request.url?.absoluteString {
            message += "URL: \(url)\n"
        }

        // Status code
        message += "Status: \(response.statusCode) "
        message += statusEmoji(for: response.statusCode)
        message += "\n"

        // Headers
        if !response.headers.isEmpty {
            message += "\nHeaders:\n"
            for (key, value) in response.headers {
                message += "  \(key): \(value)\n"
            }
        }

        // Body
        message += "\nBody:\n"
        if let jsonObject = try? JSONSerialization.jsonObject(with: response.data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            message += prettyString
        } else if let bodyString = String(data: response.data, encoding: .utf8) {
            message += bodyString
        } else {
            message += "<binary data: \(response.data.count) bytes>"
        }

        message += "\n================================\n"
        print(message)
    }

    func logError(_ error: Error, for request: URLRequest) {
        guard isEnabled else { return }

        var message = "\n================================\n"
        message += "❌ ERROR\n"
        message += "================================\n"

        if let url = request.url?.absoluteString {
            message += "URL: \(url)\n"
        }

        message += "Error: \(error.localizedDescription)\n"

        if let lyoError = error as? LyoError {
            message += "Type: \(lyoError)\n"
        }

        message += "================================\n"
        print(message)
    }

    // MARK: - Helper Methods

    private func statusEmoji(for statusCode: Int) -> String {
        switch statusCode {
        case 200...299: return "✅"
        case 300...399: return "↩️"
        case 400...499: return "⚠️"
        case 500...599: return "🔥"
        default: return "❓"
        }
    }
}
