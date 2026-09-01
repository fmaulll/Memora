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
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct UserResponse: Codable, Identifiable {

    let id: UUID
    let name: String
    let email: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case createdAt = "created_at"
    }
}

struct AnonymousUserRequest: Encodable {
    let name: String
}

struct AuthResponse: Decodable {
    let user: UserResponse
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}