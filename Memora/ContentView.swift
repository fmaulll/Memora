import SwiftUI

struct ContentView: View {
    @State private var isShowingSplash = true
    @State private var authManager = AuthManager.shared

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
            } else {
                if authManager.isAuthenticated {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            guard authManager.isAuthenticated else {
                print("NOT AUTHENTICATED — SKIPPING APP SYNC")
                return
            }

            Task {
                await AppSyncManager.shared.sync(
                    modelContext: modelContext
                )
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            guard isAuthenticated else {
                return
            }

            Task {
                await AppSyncManager.shared.sync(
                    modelContext: modelContext
                )
            }
        }

        // Text(
        //     authManager.isAuthenticated
        //         ? "Authenticated"
        //         : "Not authenticated"
        // )
    }
}

#Preview {
    ContentView()
}
