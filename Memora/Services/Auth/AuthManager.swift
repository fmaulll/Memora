import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AuthManager {

    static let shared = AuthManager()

    var isAuthenticated = false
    var currentUser: UserResponse?
    var isRestoringSession = true

    private init() {
        isAuthenticated = KeychainService.shared.hasAccessToken()
    }

    func login(
        email: String,
        password: String,
        modelContext: ModelContext
    ) async throws -> UserResponse {

        let user = try await AuthAPI.shared.login(
            email: email,
            password: password
        )

        currentUser = user
        isAuthenticated = true

        saveUserLocally(
            user,
            modelContext: modelContext
        )

        return user
    }

    func register(
        name: String,
        email: String,
        password: String,
        modelContext: ModelContext
    ) async throws -> UserResponse {

        let user = try await AuthAPI.shared.register(
            name: name,
            email: email,
            password: password
        )

        currentUser = user
        isAuthenticated = true

        saveUserLocally(
            user,
            modelContext: modelContext
        )

        return user
    }

    func logout() {
        KeychainService.shared.deleteAccessToken()
        KeychainService.shared.deleteRefreshToken()

        currentUser = nil
        isAuthenticated = false
    }

    func restoreSession(
        modelContext: ModelContext
    ) async {

        defer {
            isRestoringSession = false
        }

        guard KeychainService.shared.hasAccessToken() else {
            isAuthenticated = false
            currentUser = nil
            return
        }

        do {
            // First, try the existing access token
            let user = try await AuthAPI.shared.me()

            currentUser = user
            isAuthenticated = true

            saveUserLocally(
                user,
                modelContext: modelContext
            )

            print("SESSION RESTORED ONLINE:", user.name)

        } catch {

            print("ACCESS TOKEN FAILED:", error)

            do {
                // Access token may be expired.
                // Try to obtain a new one using the refresh token.
                try await AuthAPI.shared.refreshAccessToken()

                // Retry /auth/me using the new access token
                let user = try await AuthAPI.shared.me()

                currentUser = user
                isAuthenticated = true

                saveUserLocally(
                    user,
                    modelContext: modelContext
                )

                print("SESSION RESTORED AFTER REFRESH:", user.name)

            } catch {

                print("REFRESH TOKEN FAILED:", error)

                // Both tokens failed. The session is no longer valid.
                KeychainService.shared.deleteAccessToken()
                KeychainService.shared.deleteRefreshToken()

                currentUser = nil
                isAuthenticated = false
            }
        }
    }

    private func saveUserLocally(
        _ user: UserResponse,
        modelContext: ModelContext
    ) {

        do {

            let backendUserId = user.id

            // First, check whether this backend account
            // is already connected to a local profile.

            let userDescriptor = FetchDescriptor<LocalUserProfile>(
                predicate: #Predicate<LocalUserProfile> { profile in
                    profile.userId == backendUserId
                }
            )

            if let existingProfile = try modelContext.fetch(
                userDescriptor
            ).first {

                // Account already exists locally.
                existingProfile.name = user.name
                existingProfile.email = user.email
                existingProfile.createdAt = user.createdAt

            } else {

                // Look for the guest profile created during onboarding.
                let guestDescriptor = FetchDescriptor<LocalUserProfile>(
                    predicate: #Predicate<LocalUserProfile> {
                        profile in
                        profile.userId == nil
                    }
                )

                if let guestProfile = try modelContext.fetch(
                    guestDescriptor
                ).first {

                    // Convert guest profile into authenticated profile.
                    guestProfile.userId = user.id
                    guestProfile.email = user.email

                    // IMPORTANT:
                    // Keep the onboarding name and information.
                    //
                    // guestProfile.name stays unchanged
                    // guestProfile.educationLevel stays unchanged
                    // guestProfile.studyReason stays unchanged

                    print(
                        "GUEST PROFILE CONNECTED TO:",
                        user.email
                    )

                } else {

                    // No guest profile exists.
                    // Create a completely new profile.
                    let profile = LocalUserProfile(
                        userId: user.id,
                        name: user.name,
                        email: user.email,
                        createdAt: user.createdAt
                    )

                    modelContext.insert(profile)
                }
            }

            try modelContext.save()

        } catch {

            print(
                "Failed to save user profile locally:",
                error
            )
        }
    }

    private func loadUserLocally(
        modelContext: ModelContext
    ) -> LocalUserProfile? {

        do {

            let descriptor = FetchDescriptor<LocalUserProfile>()

            let profiles = try modelContext.fetch(descriptor)

            print("LOCAL USER PROFILES:", profiles.count)

            for profile in profiles {

                print(
                    "PROFILE:",
                    profile.id,
                    profile.name,
                    profile.email ?? "No email"
                )
            }

            return profiles.first

        } catch {

            print("❌ FAILED TO FETCH LOCAL USER:", error)

            return nil
        }
    }

    func createAnonymousUser(
        name: String,
        modelContext: ModelContext
    ) async throws {

        let response = try await AuthAPI.shared
            .createAnonymousUser(
                name: name
            )

        // Save JWT
        // Save access token
        try KeychainService.shared.saveAccessToken(
            response.accessToken
        )

        // Save refresh token
        try KeychainService.shared.saveRefreshToken(
            response.refreshToken
        )

        // Update app authentication state
        currentUser = response.user
        isAuthenticated = true

        // Save/connect local profile
        saveUserLocally(
            response.user,
            modelContext: modelContext
        )

        print("ANONYMOUS USER CREATED")
        print("USER ID:", response.user.id)
    }
}
