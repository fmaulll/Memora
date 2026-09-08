import SwiftUI
import Foundation
import Observation
import SwiftData

struct ContentView: View {

    @State private var isShowingSplash = true
    @State private var authManager = AuthManager.shared
    @State private var firstCreatedDeck: StudyDeck?

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

            guard authManager.isAuthenticated else {
                print("NOT AUTHENTICATED — SKIPPING APP SYNC")
                return
            }

            Task {
                await AppSyncManager.shared.syncIfStale(
                    modelContext: modelContext
                )
            }
        }
        .onChange(
            of: authManager.isAuthenticated
        ) { _, isAuthenticated in

            guard isAuthenticated else {
                return
            }

            Task {
                await AppSyncManager.shared.syncIfStale(
                    modelContext: modelContext
                )
            }
        }
        .task {
            await authManager.restoreSession(
                modelContext: modelContext
            )
        }
    }
}

#Preview {
    ContentView()
}