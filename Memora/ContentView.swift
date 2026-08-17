import SwiftUI

struct ContentView: View {
    @State private var isShowingSplash = true

    var body: some View {
        NavigationStack {
            if isShowingSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isShowingSplash = false
                    }
                }
            } else {
                WelcomeView()
            }
        }
    }
}

#Preview {
    ContentView()
}
