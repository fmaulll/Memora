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
            || KeychainService.shared.hasRefreshToken()
    }

    func login(
        email: String,
        password: String,
        modelContext: ModelContext
    ) async throws -> UserResponse {

        try prepareForSignIn(modelContext: modelContext)
        let revision = LocalAccountStore.shared.revision

        let user = try await AuthAPI.shared.login(
            email: email,
            password: password
        )

        try LocalAccountStore.shared.validateRevision(revision)
        try LocalAccountStore.shared.activate(userID: user.id, modelContext: modelContext)
        currentUser = user
        SubscriptionManager.shared.apply(user: user)
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

        try prepareForSignIn(modelContext: modelContext)
        let revision = LocalAccountStore.shared.revision

        _ = try await AuthAPI.shared.register(
            name: name,
            email: email,
            password: password
        )

        let user = try await AuthAPI.shared.login(email: email, password: password)

        try LocalAccountStore.shared.validateRevision(revision)
        try LocalAccountStore.shared.activate(userID: user.id, modelContext: modelContext)
        currentUser = user
        SubscriptionManager.shared.apply(user: user)
        isAuthenticated = true

        saveUserLocally(
            user,
            modelContext: modelContext
        )

        return user
    }

    func updateProfile(name: String, email: String?, modelContext: ModelContext) async throws {
        let user = try await AuthAPI.shared.updateProfile(name: name, email: email)
        currentUser = user
        SubscriptionManager.shared.apply(user: user)
        saveUserLocally(user, modelContext: modelContext)
    }

    func convertGuest(name: String, email: String, password: String, merge: Bool,
                      modelContext: ModelContext) async throws {
        guard let guest = currentUser, guest.isAnonymous else { return }
        let revision = LocalAccountStore.shared.revision
        let response: AuthResponse
        if merge {
            // Upload unsynced local work before moving the server account.
            try await SyncManager.shared.sync(modelContext: modelContext)
            try LocalAccountStore.shared.validateRevision(revision)
            response = try await AuthAPI.shared.merge(email: email, password: password)
        } else {
            response = try await AuthAPI.shared.upgrade(name: name, email: email, password: password)
        }
        try LocalAccountStore.shared.validateRevision(revision)
        // Install the new credentials first: the source guest no longer exists.
        try KeychainService.shared.saveAccessToken(response.accessToken)
        try KeychainService.shared.saveRefreshToken(response.refreshToken)
        if merge {
            try LocalAccountStore.shared.reassignAfterMerge(userID: response.user.id, modelContext: modelContext)
        }
        currentUser = response.user
        isAuthenticated = true
        SubscriptionManager.shared.apply(user: response.user)
        saveUserLocally(response.user, modelContext: modelContext)
        if merge {
            try GenerationRequestStore.shared.move(from: guest.id, to: response.user.id)
            try KeychainService.shared.moveAppleVerifications(from: guest.id, to: response.user.id)
        }
        await SubscriptionManager.shared.resume()
    }

    func logout(modelContext: ModelContext) throws {
        // Hide account views and invalidate suspended sync work before clearing.
        isAuthenticated = false
        currentUser = nil
        KeychainService.shared.deleteAccessToken()
        KeychainService.shared.deleteRefreshToken()
        SubscriptionManager.shared.reset()
        UserDefaults.standard.set(false, forKey: "hasStartedOnboarding")
        try LocalAccountStore.shared.clear(modelContext: modelContext)
    }

    private func prepareForSignIn(modelContext: ModelContext) throws {
        isAuthenticated = false
        currentUser = nil
        KeychainService.shared.deleteAccessToken()
        KeychainService.shared.deleteRefreshToken()
        SubscriptionManager.shared.reset()
        try LocalAccountStore.shared.clear(modelContext: modelContext)
    }

    func restoreSession(
        modelContext: ModelContext
    ) async {

        isRestoringSession = true

        defer {
            isRestoringSession = false
        }

        guard KeychainService.shared.hasAccessToken()
                || KeychainService.shared.hasRefreshToken() else {
            try? logout(modelContext: modelContext)
            return
        }

        // Stored credentials keep the local session available while we validate
        // them. Connectivity failures do not mean the user has signed out.
        isAuthenticated = true

        LocalAccountStore.shared.suspend()
        // Older installs may contain mixed-account data with no known owner.
        // Never expose or upload that cache under a new identity.
        if LocalAccountStore.shared.ownerID == nil {
            do {
                try LocalAccountStore.shared.clear(modelContext: modelContext)
            } catch {
                isAuthenticated = false
                print("LOCAL CACHE CLEANUP FAILED:", error)
                return
            }
        }
        let revision = LocalAccountStore.shared.revision

        do {
            let user: UserResponse

            if try KeychainService.shared.getAccessToken() == nil {
                user = try await AuthAPI.shared.refreshAccessToken().user
            } else {
                do {
                    user = try await AuthAPI.shared.me()
                } catch APIError.unauthorized {
                    try LocalAccountStore.shared.validateRevision(revision)
                    _ = try await AuthAPI.shared.refreshAccessToken()
                    user = try await AuthAPI.shared.me()
                }
            }

            try LocalAccountStore.shared.validateRevision(revision)
            isAuthenticated = false
            try LocalAccountStore.shared.activate(userID: user.id, modelContext: modelContext)
            currentUser = user
            SubscriptionManager.shared.apply(user: user)
            isAuthenticated = true
            saveUserLocally(user, modelContext: modelContext)

            print("SESSION RESTORED ONLINE:", user.name)
        } catch APIError.unauthorized {
            guard LocalAccountStore.shared.revision == revision else { return }
            // The refresh token was rejected, or the refreshed access token
            // still could not authenticate the user.
            try? logout(modelContext: modelContext)
        } catch APIError.noRefreshToken {
            guard LocalAccountStore.shared.revision == revision else { return }
            try? logout(modelContext: modelContext)
        } catch {
            guard LocalAccountStore.shared.revision == revision else { return }
            // Unowned legacy data must stay hidden if validation/cleanup fails.
            if LocalAccountStore.shared.ownerID == nil { isAuthenticated = false }
            // Keep credentials for a later retry after network/server failures.
            print("SESSION RESTORATION DEFERRED:", error)
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

        // A server outage must never turn an existing session into a new guest.
        guard try KeychainService.shared.getAccessToken() == nil,
              try KeychainService.shared.getRefreshToken() == nil else { throw APIError.existingSession }

        try prepareForSignIn(modelContext: modelContext)
        let revision = LocalAccountStore.shared.revision
        let response = try await AuthAPI.shared
            .createAnonymousUser(
                name: name
            )

        try LocalAccountStore.shared.validateRevision(revision)
        try LocalAccountStore.shared.activate(userID: response.user.id, modelContext: modelContext)

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
        SubscriptionManager.shared.apply(user: response.user)
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
