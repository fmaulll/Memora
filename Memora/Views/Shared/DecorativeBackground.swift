import SwiftUI

struct DecorativeBackground: View {
    private let bandColor = Color(red: 0.16, green: 0.17, blue: 0.40)
    
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(bandColor)
                    .frame(width: 420, height: 420)
                    .offset(x: 180, y: -360)
                    .scaleEffect(isAnimating ? 1.0 : 0.97)
                    .offset(y: isAnimating ? -6 : 6)
                    .opacity(isAnimating ? 0.42 : 0.40)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }

                Circle()
                    .fill(bandColor)
                    .frame(width: 320, height: 420)
                    .offset(x: 180, y: -360)
                    .scaleEffect(isAnimating ? 1.0 : 0.97)
                    .offset(y: isAnimating ? -6 : 6)
                    .opacity(isAnimating ? 0.42 : 0.40)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }

                Circle()
                    .fill(bandColor)
                    .frame(width: 420, height: 420)
                    .offset(x: -180, y: 360)
                    .scaleEffect(isAnimating ? 1.0 : 0.97)
                    .offset(y: isAnimating ? -6 : 6)
                    .opacity(isAnimating ? 0.42 : 0.40)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }

                Circle()
                    .fill(bandColor)
                    .frame(width: 320, height: 420)
                    .offset(x: -180, y: 360)
                    .scaleEffect(isAnimating ? 1.0 : 0.97)
                    .offset(y: isAnimating ? -6 : 6)
                    .opacity(isAnimating ? 0.42 : 0.40)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.13)
            .ignoresSafeArea()
        DecorativeBackground()
    }
}
