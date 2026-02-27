//
//  KeychainHelper.swift
//  Forge
//
//  Thin wrapper around Security framework for storing the Anthropic API key.
//  The key is stored under kSecClassGenericPassword and never leaves the device.
//

import Security
import Foundation

enum KeychainHelper {

    private static let service: String = Bundle.main.bundleIdentifier ?? "com.scopesnap.forge"
    private static let account: String = "anthropic-api-key"

    // MARK: - Save

    static func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)

        // Overwrite pattern: delete any existing entry, then add fresh.
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load

    static func loadAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    static func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience

    static var hasAPIKey: Bool {
        guard let key = loadAPIKey() else { return false }
        return !key.isEmpty
    }
}

// MARK: - Error

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed (OSStatus \(status)). Try again or restart the app."
        }
    }
}
