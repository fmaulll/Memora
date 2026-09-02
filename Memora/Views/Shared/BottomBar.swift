import SwiftUI

struct BottomBar: View {

    enum Tab {
        case home
        case library
    }

    @Binding var selectedTab: Tab
    let onAdd: () -> Void

    var body: some View {

        HStack(spacing: 0) {

            tabButton(
                .home,
                title: "Home",
                icon: "house.fill"
            )

            createButton

            tabButton(
                .library,
                title: "Library",
                icon: "books.vertical.fill"
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.appSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {

        Button(action: onAdd) {

            Image(systemName: "plus")
                .font(
                    .system(
                        size: 20,
                        weight: .bold
                    )
                )
                .foregroundStyle(Color.appBackground)
                .frame(width: 52, height: 52)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .shadow(
            color: Color.appAccent.opacity(0.25),
            radius: 12,
            y: 6
        )
        .frame(maxWidth: .infinity)
        .accessibilityLabel(
            "Create a new study deck"
        )
    }

    // MARK: - Tab Button

    private func tabButton(
        _ tab: Tab,
        title: String,
        icon: String
    ) -> some View {

        Button {

            selectedTab = tab

        } label: {

            VStack(spacing: 6) {

                Image(
                    systemName: icon
                )
                .font(
                    .system(
                        size: 20,
                        weight: .medium
                    )
                )

                Text(title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 12
                        )
                    )
            }
            .foregroundStyle(
                selectedTab == tab
                ? Color.appAccent
                : Color.appTextSecondary
            )
            .frame(
                maxWidth: .infinity
            )
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(
            selectedTab == tab
            ? .isSelected
            : []
        )
    }
}