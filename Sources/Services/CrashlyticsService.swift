import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
import os
#endif

// MARK: - Crashlytics Service
/// Centralized service for crash reporting and error logging
final class CrashlyticsService {
    static let shared = CrashlyticsService()
    private init() {}
    
    // MARK: - User Identification
    
    /// Set user ID for crash reports
    func setUserId(_ userId: String?) {
        #if canImport(FirebaseCrashlytics)
        if let userId = userId {
            Crashlytics.crashlytics().setUserID(userId)
            UserDefaults.standard.set(userId, forKey: "currentUserId")
        } else {
            Crashlytics.crashlytics().setUserID("")
            UserDefaults.standard.removeObject(forKey: "currentUserId")
        }
        #endif
    }
    
    /// Set custom key-value for crash reports
    func setCustomValue(_ value: Any, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
    
    // MARK: - Error Logging
    
    /// Log a non-fatal error
    func logError(_ error: Error, context: String? = nil) {
        #if canImport(FirebaseCrashlytics)
        var userInfo: [String: Any] = [:]
        if let context = context {
            userInfo["context"] = context
        }
        
        let nsError = NSError(
            domain: (error as NSError).domain,
            code: (error as NSError).code,
            userInfo: userInfo
        )
        Crashlytics.crashlytics().record(error: nsError)
        #endif
        
        // Also log locally in debug
        #if DEBUG
        Log.net.error("[CrashlyticsService] Error logged: \(error.localizedDescription)")
        if let context = context {
            Log.net.info("   Context: \(context)")
        }
        #endif
    }
    
    /// Log a non-fatal error with custom message
    func logError(message: String, code: Int = 0, domain: String = "com.lyo.app") {
        #if canImport(FirebaseCrashlytics)
        let error = NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
        Crashlytics.crashlytics().record(error: error)
        #endif
        
        #if DEBUG
        Log.net.error("[CrashlyticsService] Error: \(message)")
        #endif
    }
    
    // MARK: - Breadcrumbs (Log Messages)
    
    /// Log a message/breadcrumb
    func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
        
        #if DEBUG
        Log.net.error("[Crashlytics] \(message)")
        #endif
    }
    
    // MARK: - API Error Logging
    
    /// Log an API failure
    func logAPIError(endpoint: String, statusCode: Int?, error: Error?) {
        #if canImport(FirebaseCrashlytics)
        var userInfo: [String: Any] = [
            "endpoint": endpoint
        ]
        if let statusCode = statusCode {
            userInfo["statusCode"] = statusCode
        }
        
        let nsError = NSError(
            domain: "com.lyo.api",
            code: statusCode ?? -1,
            userInfo: userInfo
        )
        Crashlytics.crashlytics().record(error: nsError)
        #endif
        
        #if DEBUG
        Log.net.error("[API Error] \(endpoint) - Status: \(statusCode ?? -1)")
        if let error = error {
            Log.net.error("   Error: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Screen/Feature Tracking
    
    /// Log when user enters a screen/feature
    func logScreen(_ screenName: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("Screen: \(screenName)")
        Crashlytics.crashlytics().setCustomValue(screenName, forKey: "last_screen")
        #endif
    }
    
    /// Log a user action
    func logAction(_ action: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        var message = "Action: \(action)"
        if let params = parameters {
            message += " - \(params)"
        }
        Crashlytics.crashlytics().log(message)
        #endif
    }
}
