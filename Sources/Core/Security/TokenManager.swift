import Foundation
import Security

// MARK: - Token Manager
/// Secure storage for authentication tokens using Keychain
actor TokenManager {

    static let shared = TokenManager()

    // MARK: - Keychain Keys
    private enum KeychainKey {
        static let accessToken = "com.lyo.app.accessToken"
        static let refreshToken = "com.lyo.app.refreshToken"
        static let tenantId = "com.lyo.app.tenantId"
        static let userId = "com.lyo.app.userId"
    }

    // MARK: - Public API

    func getToken() async -> String? {
        return await keychainRead(key: KeychainKey.accessToken)
    }

    func setToken(_ token: String) async {
        await keychainWrite(key: KeychainKey.accessToken, value: token)
    }

    func getRefreshToken() async -> String? {
        return await keychainRead(key: KeychainKey.refreshToken)
    }

    func setRefreshToken(_ token: String) async {
        await keychainWrite(key: KeychainKey.refreshToken, value: token)
    }

    func getTenantId() async -> String? {
        return await keychainRead(key: KeychainKey.tenantId)
    }

    func setTenantId(_ id: String) async {
        await keychainWrite(key: KeychainKey.tenantId, value: id)
    }

    func getUserId() async -> String? {
        return await keychainRead(key: KeychainKey.userId)
    }

    func setUserId(_ id: String) async {
        await keychainWrite(key: KeychainKey.userId, value: id)
    }

    func clearAll() async {
        await keychainDelete(key: KeychainKey.accessToken)
        await keychainDelete(key: KeychainKey.refreshToken)
        await keychainDelete(key: KeychainKey.tenantId)
        await keychainDelete(key: KeychainKey.userId)
    }

    // MARK: - Keychain Operations

    private func keychainRead(key: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func keychainWrite(key: String, value: String) async {
        guard let data = value.data(using: .utf8) else { return }

        // Check if item already exists
        let existingQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(existingQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, create it
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func keychainDelete(key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
