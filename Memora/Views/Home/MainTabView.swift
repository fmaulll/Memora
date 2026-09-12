import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: BottomBar.Tab = .home
    @State private var isShowingNewStudyDeck = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(BottomBar.Tab.home)

            NavigationStack {
                LibraryView()
            }
            .tag(BottomBar.Tab.library)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(selectedTab: $selectedTab) {
                isShowingNewStudyDeck = true
            }
        }
        .navigationDestination(isPresented: $isShowingNewStudyDeck) {
            NavigationStack {
                NewStudyDeckView { deck in
                    isShowingNewStudyDeck = false
                    selectedTab = .library
                }
            }
        }
    }
}