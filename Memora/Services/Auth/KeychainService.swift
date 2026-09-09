import Foundation
import Security

final class KeychainService {

    static let shared = KeychainService()

    init(service: String = "com.memora.app") { self.service = service }

    private let service: String
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

    // Signed restore transactions may already be finished in StoreKit, so keep
    // an account-scoped retry copy in Keychain as well as StoreKit's queue.
    func pendingAppleVerifications(userID: UUID) throws -> [String: String] {
        guard let json = try getToken(key: "apple_pending_\(userID.uuidString)") else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: Data(json.utf8))
    }

    func saveAppleVerifications(_ pending: [String: String], userID: UUID) throws {
        let key = "apple_pending_\(userID.uuidString)"
        if pending.isEmpty { deleteToken(key: key); return }
        let data = try JSONEncoder().encode(pending)
        try saveToken(String(decoding: data, as: UTF8.self), key: key)
    }

    func moveAppleVerifications(from source: UUID, to destination: UUID) throws {
        var pending = try pendingAppleVerifications(userID: destination)
        pending.merge(try pendingAppleVerifications(userID: source)) { existing, _ in existing }
        try saveAppleVerifications(pending, userID: destination)
        try saveAppleVerifications([:], userID: source)
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