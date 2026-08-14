//
//  NavigationButton.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI

struct NavigationButton<Destination: View>: View {

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
    let destination: Destination

    init(
        title: String,
        icon: Icon? = nil,
        iconPosition: IconPosition = .left,
        foreground: Color = .white,
        background: (any ShapeStyle)? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.icon = icon
        self.iconPosition = iconPosition
        self.foreground = foreground
        self.destination = destination()

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
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                if iconPosition == .left { iconView }

                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))

                if iconPosition == .right { iconView }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
