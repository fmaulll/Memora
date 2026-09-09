import SwiftUI
import Foundation
import Observation
import SwiftData

struct ContentView: View {

    @State private var isShowingSplash = true
    @State private var subscriptions = SubscriptionManager.shared
    @State private var authManager = AuthManager.shared
    @State private var firstCreatedDeck: StudyDeck?
    @State private var didStartRestoringSession = false

    @AppStorage("hasCompletedOnboarding")
    private var hasCompletedOnboarding = false

    @AppStorage("hasStartedOnboarding")
    private var hasStartedOnboarding = false

    private var rootRoute: String {
        if isShowingSplash || authManager.isRestoringSession { return "loading" }
        if !hasCompletedOnboarding && hasStartedOnboarding { return "onboarding" }
        return authManager.isAuthenticated && hasCompletedOnboarding ? "home" : "welcome"
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {

        NavigationStack {

            if isShowingSplash {

                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isShowingSplash = false
                    }
                }

            } else if authManager.isRestoringSession {

                ProgressView("Restoring session…")

            } else if !hasCompletedOnboarding && hasStartedOnboarding {

                OnboardingView { createdDeck in
                    firstCreatedDeck = createdDeck
                }

            } else if authManager.isAuthenticated && hasCompletedOnboarding {

                HomeView(initialDeck: firstCreatedDeck)

            } else {

                WelcomeView(
                    onGetStarted: {
                        hasCompletedOnboarding = false
                        hasStartedOnboarding = true
                    },
                    onLoggedIn: {
                        hasCompletedOnboarding = true
                        hasStartedOnboarding = false
                    }
                )
            }
        }
        .id(rootRoute)
        .onChange(of: scenePhase) { _, newPhase in

            guard newPhase == .active else {
                return
            }

            guard authManager.isAuthenticated, !authManager.isRestoringSession else {
                print("NOT AUTHENTICATED — SKIPPING APP SYNC")
                return
            }

            Task {
                if (try? LocalAccountStore.shared.session()) == nil {
                    await authManager.restoreSession(modelContext: modelContext)
                }
                await subscriptions.resume()
                await AppSyncManager.shared.syncIfStale(
                    modelContext: modelContext
                )
            }
        }
        .onChange(
            of: authManager.isAuthenticated
        ) { _, isAuthenticated in

            guard isAuthenticated else {
                firstCreatedDeck = nil
                return
            }

            Task {
                await subscriptions.resume()
                await AppSyncManager.shared.syncIfStale(
                    modelContext: modelContext
                )
            }
        }
        .task {
            guard !didStartRestoringSession else { return }
            didStartRestoringSession = true
            await authManager.restoreSession(
                modelContext: modelContext
            )
            await subscriptions.resume()
            await AppSyncManager.shared.syncIfStale(modelContext: modelContext)
        }
    }
}

#Preview {
    ContentView()
}