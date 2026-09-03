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
                        .appAccent,
                        .appAccent
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
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
