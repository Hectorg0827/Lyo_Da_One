import Foundation
import UserNotifications
import UIKit

// MARK: - Push Notification Service

/// Service for managing push notifications with the Lyo backend.
/// Handles device registration, preferences, and notification permissions.
final class PushNotificationService: NSObject {
    static let shared = PushNotificationService()
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    // Cached device token
    private var deviceToken: String?
    private var isRegisteredWithBackend = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Request Permission
    
    /// Request push notification permission from the user
    func requestPermission(completion: @escaping (Bool, Error?) -> Void) {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Push notification permission granted")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    print("❌ Push notification permission denied")
                }
                completion(granted, error)
            }
        }
    }
    
    /// Check current notification authorization status
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Device Token Management
    
    /// Called by AppDelegate when device token is received
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("📱 Device token received: \(tokenString.prefix(20))...")
        
        // Auto-register with backend if user is logged in
        Task {
            await registerDeviceIfNeeded()
        }
    }
    
    /// Called by AppDelegate when registration fails
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Backend Registration
    
    /// Register device with the Lyo backend
    func registerDeviceWithBackend() async throws -> PushDeviceResponse {
        guard let token = deviceToken else {
            throw PushNotificationError.noDeviceToken
        }
        
        guard await tokenManager.getToken() != nil else {
            throw PushNotificationError.notAuthenticated
        }
        
        let osVersion = await MainActor.run { UIDevice.current.systemVersion }
        
        let request = DeviceRegistrationRequest(
            deviceToken: token,
            deviceType: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            osVersion: osVersion
        )
        
        let url = URL(string: "\(baseURL)/api/v1/push/devices/register")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PushNotificationError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            let deviceResponse = try decoder.decode(PushDeviceResponse.self, from: data)
            isRegisteredWithBackend = true
            print("✅ Device registered with backend: \(deviceResponse.id)")
            return deviceResponse
            
        case 401:
            throw PushNotificationError.notAuthenticated
            
        default:
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw PushNotificationError.serverError(errorMessage)
            }
            throw PushNotificationError.serverError("Registration failed with status \(httpResponse.statusCode)")
        }
    }
    
    /// Auto-register when user logs in or token is received
    private func registerDeviceIfNeeded() async {
        guard deviceToken != nil, await tokenManager.getToken() != nil, !isRegisteredWithBackend else {
            return
        }
        
        do {
            _ = try await registerDeviceWithBackend()
        } catch {
            print("⚠️ Auto device registration failed: \(error.localizedDescription)")
        }
    }
    
    /// Called when user logs in - trigger device registration
    func onUserLogin() {
        Task {
            await registerDeviceIfNeeded()
        }
    }
    
    /// Called when user logs out - unregister device
    func onUserLogout() {
        isRegisteredWithBackend = false
        // Optionally call unregister endpoint here
    }
    
    // MARK: - Get Registered Devices
    
    /// List all devices registered for the current user
    func getRegisteredDevices() async throws -> [PushDeviceResponse] {
        guard await tokenManager.getToken() != nil else {
            throw PushNotificationError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/push/devices")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PushNotificationError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([PushDeviceResponse].self, from: data)
    }
    
    // MARK: - Unregister Device
    
    /// Unregister a specific device
    func unregisterDevice(deviceId: String) async throws {
        guard await tokenManager.getToken() != nil else {
            throw PushNotificationError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/push/devices/\(deviceId)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PushNotificationError.invalidResponse
        }
        
        isRegisteredWithBackend = false
        print("✅ Device unregistered from backend")
    }
    
    // MARK: - Notification Preferences
    
    /// Get user's notification preferences from backend
    func getPreferences() async throws -> NotificationPreferences {
        guard await tokenManager.getToken() != nil else {
            throw PushNotificationError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/push/preferences")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PushNotificationError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NotificationPreferences.self, from: data)
    }
    
    /// Update user's notification preferences
    func updatePreferences(_ preferences: NotificationPreferences) async throws -> NotificationPreferences {
        guard await tokenManager.getToken() != nil else {
            throw PushNotificationError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/push/preferences")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(preferences)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PushNotificationError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NotificationPreferences.self, from: data)
    }
    
    // MARK: - Test Notification
    
    /// Send a test notification to verify setup
    func sendTestNotification(title: String = "Test from Lyo", body: String = "Push notifications are working!") async throws {
        guard await tokenManager.getToken() != nil else {
            throw PushNotificationError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/push/test")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            urlRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let request = TestNotificationRequest(title: title, body: body)
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PushNotificationError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            print("✅ Test notification sent")
        case 400:
            throw PushNotificationError.noActiveDevices
        default:
            if let errorMessage = String(data: data, encoding: .utf8) {
                throw PushNotificationError.serverError(errorMessage)
            }
            throw PushNotificationError.serverError("Failed with status \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Handle Incoming Notifications
    
    /// Process a notification payload when app is in foreground
    func handleForegroundNotification(_ notification: UNNotification) {
        let content = notification.request.content
        print("📬 Foreground notification: \(content.title) - \(content.body)")
        
        // Extract custom data
        let userInfo = content.userInfo
        if let action = userInfo["action"] as? String {
            handleNotificationAction(action, data: userInfo)
        }
    }
    
    /// Process notification tap when user interacts with it
    func handleNotificationTap(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")
        
        if let action = userInfo["action"] as? String {
            handleNotificationAction(action, data: userInfo)
        }
    }
    
    /// Handle specific notification actions
    private func handleNotificationAction(_ action: String, data: [AnyHashable: Any]) {
        switch action {
        case "open_course":
            if let courseId = data["courseId"] as? String {
                NotificationCenter.default.post(
                    name: .openCourse,
                    object: nil,
                    userInfo: ["courseId": courseId]
                )
            }
            
        case "open_achievement":
            if let achievementId = data["achievementId"] as? String {
                NotificationCenter.default.post(
                    name: .openAchievement,
                    object: nil,
                    userInfo: ["achievementId": achievementId]
                )
            }
            
        case "open_feed":
            NotificationCenter.default.post(name: .openFeed, object: nil)
            
        case "open_chat":
            NotificationCenter.default.post(name: .openChat, object: nil)
            
        default:
            print("⚠️ Unknown notification action: \(action)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handleForegroundNotification(notification)
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationTap(response)
        completionHandler()
    }
}

// MARK: - Request Models

struct DeviceRegistrationRequest: Codable {
    let deviceToken: String
    let deviceType: String
    let appVersion: String?
    let osVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case deviceToken = "device_token"
        case deviceType = "device_type"
        case appVersion = "app_version"
        case osVersion = "os_version"
    }
}

struct TestNotificationRequest: Codable {
    let title: String
    let body: String
    let data: [String: String]?
    let badgeCount: Int?
    let sound: String?
    
    init(title: String, body: String, data: [String: String]? = nil, badgeCount: Int? = nil, sound: String? = "default") {
        self.title = title
        self.body = body
        self.data = data
        self.badgeCount = badgeCount
        self.sound = sound
    }
    
    enum CodingKeys: String, CodingKey {
        case title, body, data, sound
        case badgeCount = "badge_count"
    }
}

// MARK: - Response Models

struct PushDeviceResponse: Codable, Identifiable {
    let id: String
    let deviceToken: String
    let deviceType: String
    let appVersion: String?
    let osVersion: String?
    let isActive: Bool
    let registeredAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case deviceToken = "device_token"
        case deviceType = "device_type"
        case appVersion = "app_version"
        case osVersion = "os_version"
        case isActive = "is_active"
        case registeredAt = "registered_at"
    }
}

struct NotificationPreferences: Codable {
    var courseReminders: Bool
    var achievementNotifications: Bool
    var feedUpdates: Bool
    var marketingNotifications: Bool
    var quietHoursStart: String?
    var quietHoursEnd: String?
    var timezone: String
    
    init(
        courseReminders: Bool = true,
        achievementNotifications: Bool = true,
        feedUpdates: Bool = true,
        marketingNotifications: Bool = false,
        quietHoursStart: String? = nil,
        quietHoursEnd: String? = nil,
        timezone: String = "UTC"
    ) {
        self.courseReminders = courseReminders
        self.achievementNotifications = achievementNotifications
        self.feedUpdates = feedUpdates
        self.marketingNotifications = marketingNotifications
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.timezone = timezone
    }
}

// MARK: - Errors

enum PushNotificationError: LocalizedError {
    case noDeviceToken
    case notAuthenticated
    case invalidResponse
    case noActiveDevices
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .noDeviceToken:
            return "No device token available. Please enable notifications."
        case .notAuthenticated:
            return "Please log in to manage notifications."
        case .invalidResponse:
            return "Invalid response from server."
        case .noActiveDevices:
            return "No active devices registered for notifications."
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openCourse = Notification.Name("LyoOpenCourse")
    static let openAchievement = Notification.Name("LyoOpenAchievement")
    static let openFeed = Notification.Name("LyoOpenFeed")
    static let openChat = Notification.Name("LyoOpenChat")
}
