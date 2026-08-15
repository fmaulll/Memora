import SwiftUI

struct DecorativeBackground: View {
    private let bandColor = Color(red: 0.16, green: 0.17, blue: 0.40)
    
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                
                Circle()
                    .fill(bandColor.opacity(0.42))
                    .frame(width: 420, height: 420)
                    .offset(x: 180, y: -360)

                Circle()
                    .fill(bandColor.opacity(0.42))
                    .frame(width: 320, height: 420)
                    .offset(x: 180, y: -360)

                Circle()
                    .fill(bandColor.opacity(0.42))
                    .frame(width: 420, height: 420)
                    .offset(x: -180, y: 360)

                Circle()
                    .fill(bandColor.opacity(0.42))
                    .frame(width: 320, height: 420)
                    .offset(x: -180, y: 360)
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
