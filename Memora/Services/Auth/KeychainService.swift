import Foundation
import Security

final class KeychainService {

    static let shared = KeychainService()

    private init() {}

    private let service = "com.memora.app"
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"

    // MARK: - Access Token

    func saveAccessToken(_ token: String) throws {
        try saveToken(token, key: accessTokenKey)
    }

    func getAccessToken() throws -> String? {
        try getToken(key: accessTokenKey)
    }

    func deleteAccessToken() {
        deleteToken(key: accessTokenKey)
    }

    func hasAccessToken() -> Bool {
        (try? getAccessToken()) != nil
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) throws {
        try saveToken(token, key: refreshTokenKey)
    }

    func getRefreshToken() throws -> String? {
        try getToken(key: refreshTokenKey)
    }

    func deleteRefreshToken() {
        deleteToken(key: refreshTokenKey)
    }

    func hasRefreshToken() -> Bool {
        (try? getRefreshToken()) != nil
    }

    // MARK: - Generic Keychain Methods

    private func saveToken(_ token: String, key: String) throws {
        let data = Data(token.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func getToken(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.readFailed(status)
        }

        return token
    }

    private func deleteToken(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}


// MARK: - Errors

enum KeychainError: LocalizedError {
    case invalidData
    case saveFailed(OSStatus)
    case readFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Unable to encode keychain data."

        case .saveFailed(let status):
            return "Failed to save token to Keychain. Status: \(status)"

        case .readFailed(let status):
            return "Failed to read token from Keychain. Status: \(status)"
        }
    }
}