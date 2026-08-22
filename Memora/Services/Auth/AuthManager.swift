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

        currentUser = nil
        isAuthenticated = false
    }   

    func restoreSession(
        modelContext: ModelContext
    ) async {

        guard KeychainService.shared.hasAccessToken() else {
            isAuthenticated = false
            currentUser = nil
            isRestoringSession = false
            return
        }

        do {
            let user = try await AuthAPI.shared.me()

            currentUser = user
            isAuthenticated = true

            saveUserLocally(
                user,
                modelContext: modelContext
            )

            print("SESSION RESTORED ONLINE:", user.name)

        } catch {

            print("SESSION RESTORE FAILED:", error)

            let localUser = loadUserLocally(
                modelContext: modelContext
            )

            if let localUser {

                print("LOCAL USER FOUND")
                print("LOCAL ID:", localUser.id)
                print("LOCAL NAME:", localUser.name)
                print("LOCAL EMAIL:", localUser.email)

                currentUser = UserResponse(
                    id: localUser.id,
                    name: localUser.name,
                    email: localUser.email,
                    createdAt: localUser.createdAt
                )

                isAuthenticated = true

            } else {

                print("❌ NO LOCAL USER PROFILE FOUND")

                currentUser = nil
                isAuthenticated = false
            }
        }

        isRestoringSession = false
    }

    private func saveUserLocally(
        _ user: UserResponse,
        modelContext: ModelContext
    ) {

        do {

            let descriptor = FetchDescriptor<LocalUserProfile>(
                predicate: #Predicate<LocalUserProfile> { profile in
                    profile.id == user.id
                }
            )

            if let existingProfile = try modelContext.fetch(
                descriptor
            ).first {

                existingProfile.name = user.name
                existingProfile.email = user.email
                existingProfile.createdAt = user.createdAt

            } else {

                let profile = LocalUserProfile(
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    createdAt: user.createdAt
                )

                modelContext.insert(profile)
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
                    profile.email
                )
            }

            return profiles.first

        } catch {

            print("❌ FAILED TO FETCH LOCAL USER:", error)

            return nil
        }
    }
}