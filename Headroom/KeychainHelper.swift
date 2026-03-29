import Foundation
import Security

/// Stores and retrieves the session cookie securely in the macOS Keychain.
enum KeychainHelper {
    private static let service = "net.stupendous.headroom"
    private static let sessionKeyAccount = "sessionKey"
    private static let orgIdAccount = "orgId"
    private static let orgNameAccount = "orgName"

    // MARK: - Session Key

    static func saveSessionKey(_ key: String) -> Bool {
        return save(account: sessionKeyAccount, data: key)
    }

    static func loadSessionKey() -> String? {
        return load(account: sessionKeyAccount)
    }

    static func deleteSessionKey() {
        delete(account: sessionKeyAccount)
    }

    // MARK: - Org ID

    static func saveOrgId(_ id: String) -> Bool {
        return save(account: orgIdAccount, data: id)
    }

    static func loadOrgId() -> String? {
        return load(account: orgIdAccount)
    }

    // MARK: - Org Name

    static func saveOrgName(_ name: String) -> Bool {
        return save(account: orgNameAccount, data: name)
    }

    static func loadOrgName() -> String? {
        return load(account: orgNameAccount)
    }

    // MARK: - Clear All

    static func clearAll() {
        delete(account: sessionKeyAccount)
        delete(account: orgIdAccount)
        delete(account: orgNameAccount)
    }

    // MARK: - Private

    private static func save(account: String, data: String) -> Bool {
        guard let data = data.data(using: .utf8) else { return false }

        // Delete existing item first
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
