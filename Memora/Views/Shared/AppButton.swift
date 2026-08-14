import SwiftUI

struct AppButton: View {

    enum Icon {
        case sf(String)
        case asset(String)
    }

    enum IconPosition {
        case left
        case right
    }

    let title: String
    let icon: Icon?
    let iconPosition: IconPosition
    let foreground: Color
    let background: AnyShapeStyle
    let action: () -> Void

    init(
        title: String,
        icon: Icon? = nil,
        iconPosition: IconPosition = .left,
        foreground: Color = .white,
        background: (any ShapeStyle)? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconPosition = iconPosition
        self.foreground = foreground
        
        if let background {
            self.background = AnyShapeStyle(background)
        } else {
            self.background = AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.39, green: 0.40, blue: 0.95),
                        Color(red: 0.55, green: 0.36, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if iconPosition == .left {
                    iconView
                }

                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))

                if iconPosition == .right {
                    iconView
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
        }
        .foregroundStyle(foreground)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            switch icon {
            case .sf(let name):
                Image(systemName: name)
                    .font(.system(size: 18))

            case .asset(let name):
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
        }
    }
}

//#Preview {
//    VStack(spacing: 16) {
//
//        AppButton(
//            title: "Continue with Apple",
//            icon: .sf("apple.logo"),
//            foreground: .black,
//            background: .white
//        ) {}
//
//        AppButton(
//            title: "Continue with Google",
//            icon: .asset("GoogleIcon"),
//            background: .blue
//        ) {}
//
//        AppButton(
//            title: "Get Started",
//            background: .indigo
//        ) {}
//
//        AppButton(
//            title: "Next",
//            icon: .sf("arrow.right"),
//            iconPosition: .right,
//            background: .purple
//        ) {}
//    }
//    .padding()
//}
