import Foundation

struct RegisterRequest: Encodable {
    let name: String
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct UserUpdateRequest: Encodable {
    let name: String?
    let email: String?
}

struct TokenResponse: Decodable {
    let user: UserResponse
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct UserResponse: Codable, Identifiable {

    let id: UUID
    let name: String
    let email: String
    let createdAt: Date
    let isAnonymous: Bool
    let appAccountToken: UUID
    let freeAIDeckAvailable: Bool
    let entitlement: SubscriptionEntitlement

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case createdAt = "created_at"
        case isAnonymous = "is_anonymous"
        case appAccountToken = "app_account_token"
        case freeAIDeckAvailable = "free_ai_deck_available"
        case entitlement
    }
}

struct AnonymousUserRequest: Encodable {
    let name: String
}

struct AuthResponse: Decodable {
    let user: UserResponse
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}