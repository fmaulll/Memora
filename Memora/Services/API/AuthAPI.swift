import Foundation

@MainActor
final class AuthAPI {

    static let shared = AuthAPI()

    private let client: APIClient
    private let keychain: KeychainService

    init(client: APIClient = .shared, keychain: KeychainService = .shared) {
        self.client = client
        self.keychain = keychain
    }

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

        return try await client.request(
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
        let revision = LocalAccountStore.shared.revision

        let request = LoginRequest(
            email: email,
            password: password
        )

        let response: TokenResponse = try await client.request(
            endpoint: "/auth/login",
            method: .post,
            body: request,
            authenticated: false
        )

        try LocalAccountStore.shared.validateRevision(revision)

        try keychain.saveAccessToken(
            response.accessToken
        )

        try keychain.saveRefreshToken(
            response.refreshToken
        )

        return response.user
    }

    // MARK: - Current User

    func me() async throws -> UserResponse {

        return try await client.request(
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

        return try await client.request(
            endpoint: "/auth/me",
            method: .put,
            body: request
        )
    }

    // MARK: - Anonymous User

    func createAnonymousUser(
        name: String
    ) async throws -> AuthResponse {
        guard try keychain.getAccessToken() == nil,
              try keychain.getRefreshToken() == nil else { throw APIError.existingSession }
        let revision = LocalAccountStore.shared.revision

        let requestBody = AnonymousUserRequest(
            name: name
        )

        let response: AuthResponse = try await client.request(
            endpoint: "/auth/anonymous",
            method: .post,
            body: requestBody,
            authenticated: false
        )

        try LocalAccountStore.shared.validateRevision(revision)

        try keychain.saveAccessToken(
            response.accessToken
        )

        try keychain.saveRefreshToken(
            response.refreshToken
        )

        return response
    }

    // MARK: - Refresh Token

    private var refreshTask: Task<TokenResponse, Error>?
    func refreshAccessToken() async throws -> TokenResponse {
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> TokenResponse {
        let revision = LocalAccountStore.shared.revision

        guard let refreshToken = try keychain.getRefreshToken() else {
            throw APIError.noRefreshToken
        }

        let request = RefreshTokenRequest(
            refreshToken: refreshToken
        )

        let response: TokenResponse = try await client.request(
            endpoint: "/auth/refresh",
            method: .post,
            body: request,
            authenticated: false
        )

        try LocalAccountStore.shared.validateRevision(revision)

        try keychain.saveAccessToken(
            response.accessToken
        )

        try keychain.saveRefreshToken(
            response.refreshToken
        )

        if AuthManager.shared.currentUser?.id == response.user.id {
            AuthManager.shared.currentUser = response.user
            SubscriptionManager.shared.apply(user: response.user)
        }
        return response
    }

    func upgrade(name: String, email: String, password: String) async throws -> AuthResponse {
        try await client.request(endpoint: "/auth/upgrade", method: .post,
                                           body: RegisterRequest(name: name, email: email, password: password))
    }
    func merge(email: String, password: String) async throws -> AuthResponse {
        try await client.request(endpoint: "/auth/merge", method: .post,
                                           body: LoginRequest(email: email, password: password))
    }
}
