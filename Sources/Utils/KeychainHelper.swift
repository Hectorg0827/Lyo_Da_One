import Foundation
import Security

// MARK: - Keychain Helper
/// A helper class for securely storing and retrieving data from the iOS Keychain
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}
    
    private let service = "com.lyo.app"
    
    /// Save data to Keychain
    func save(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain save failed: \(status)")
        }
    }
    
    /// Save string to Keychain
    func saveString(_ string: String, forKey key: String) {
        if let data = string.data(using: .utf8) {
            save(data, forKey: key)
        }
    }
    
    /// Read data from Keychain
    func read(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    /// Read string from Keychain
    func readString(forKey key: String) -> String? {
        guard let data = read(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Delete item from Keychain
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            print("⚠️ Keychain delete failed: \(status)")
        }
    }
    
    /// Check if key exists in Keychain
    func exists(forKey key: String) -> Bool {
        return read(forKey: key) != nil
    }
}
