import Foundation

final class AuthAPI {

    static let shared = AuthAPI()

    private init() {}

    // MARK: - Register

    func register(
        name: String,
        email: String,
        password: String
    ) async throws -> UserResponse {

        let request = RegisterRequest(
            name: name,
            email: email,
            password: password
        )

        return try await APIClient.shared.request(
            endpoint: "/auth/register",
            method: .post,
            body: request,
            authenticated: false
        )
    }

    // MARK: - Login

    func login(
        email: String,
        password: String
    ) async throws -> UserResponse {

        let request = LoginRequest(
            email: email,
            password: password
        )

        let response: TokenResponse = try await APIClient.shared.request(
            endpoint: "/auth/login",
            method: .post,
            body: request,
            authenticated: false
        )

        try KeychainService.shared.saveAccessToken(
            response.accessToken
        )

        try KeychainService.shared.saveRefreshToken(
            response.refreshToken
        )

        return try await me()
    }

    // MARK: - Current User

    func me() async throws -> UserResponse {

        return try await APIClient.shared.request(
            endpoint: "/auth/me",
            method: .get
        )
    }

    // MARK: - Update Profile

    func updateProfile(
        name: String? = nil,
        email: String? = nil
    ) async throws -> UserResponse {

        let request = UserUpdateRequest(
            name: name,
            email: email
        )

        return try await APIClient.shared.request(
            endpoint: "/auth/me",
            method: .put,
            body: request
        )
    }

    // MARK: - Logout

    func logout() {
        KeychainService.shared.deleteAccessToken()
        KeychainService.shared.deleteRefreshToken()
    }

    // MARK: - Anonymous User

    func createAnonymousUser(
        name: String
    ) async throws -> AuthResponse {

        let requestBody = AnonymousUserRequest(
            name: name
        )

        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/anonymous",
            method: .post,
            body: requestBody
        )

        try KeychainService.shared.saveAccessToken(
            response.accessToken
        )

        try KeychainService.shared.saveRefreshToken(
            response.refreshToken
        )

        return response
    }

    // MARK: - Refresh Token

    func refreshAccessToken() async throws -> TokenResponse {

        guard let refreshToken = try KeychainService.shared.getRefreshToken() else {
            throw APIError.noRefreshToken
        }

        let request = RefreshTokenRequest(
            refreshToken: refreshToken
        )

        let response: TokenResponse = try await APIClient.shared.request(
            endpoint: "/auth/refresh",
            method: .post,
            body: request,
            authenticated: false
        )

        try KeychainService.shared.saveAccessToken(
            response.accessToken
        )

        try KeychainService.shared.saveRefreshToken(
            response.refreshToken
        )

        return response
    }
}