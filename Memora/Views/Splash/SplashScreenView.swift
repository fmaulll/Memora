import SwiftUI

struct SplashScreenView: View {
    let onFinished: () -> Void

    @State private var isGlowing = false
    @State private var hasAppeared = false

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            Circle()
                .fill(accent.opacity(isGlowing ? 0.35 : 0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .scaleEffect(isGlowing ? 1.08 : 0.92)

            Image("MemoraLogoVioletNoBg")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
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
