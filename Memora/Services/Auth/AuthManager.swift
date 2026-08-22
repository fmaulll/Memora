import Foundation
import Observation

@MainActor
@Observable
final class AuthManager {

    static let shared = AuthManager()

    var isAuthenticated = false
    var currentUser: UserResponse?

    private init() {
        isAuthenticated = KeychainService.shared.hasAccessToken()
    }

    func login(
        email: String,
        password: String
    ) async throws -> UserResponse {

        let user = try await AuthAPI.shared.login(
            email: email,
            password: password
        )

        currentUser = user
        isAuthenticated = true

        return user
    }

    func register(
        name: String,
        email: String,
        password: String
    ) async throws -> UserResponse {

        let user = try await AuthAPI.shared.register(
            name: name,
            email: email,
            password: password
        )

        currentUser = user
        isAuthenticated = true

        return user
    }

    func logout() {
        do {
            try KeychainService.shared.deleteAccessToken()
        } catch {
            print("Logout error:", error)
        }

        currentUser = nil
        isAuthenticated = false
    }
}