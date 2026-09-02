import SwiftUI

struct SplashScreenView: View {
    let onFinished: () -> Void

    @State private var isGlowing = false
    @State private var hasAppeared = false

    private let background = Color.appBackground
    private let accent = Color.appAccent

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            Circle()
                .fill(accent.opacity(isGlowing ? 0.35 : 0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .scaleEffect(isGlowing ? 1.08 : 0.92)

            Image("MrEdLeaningReading")
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isGlowing = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFinished()
            }
        }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
