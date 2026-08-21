import Foundation
import Security

final class KeychainService {

    static let shared = KeychainService()

    private init() {}

    private let service = "com.memora.app"
    private let accessTokenKey = "access_token"

    // MARK: - Access Token

    func saveAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // Remove existing token first
        deleteAccessToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(
            query as CFDictionary,
            nil
        )

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func getAccessToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
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

        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.invalidData
        }

        return token
    }

    func deleteAccessToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    func hasAccessToken() -> Bool {
        do {
            return try getAccessToken() != nil
        } catch {
            return false
        }
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