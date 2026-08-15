import SwiftUI

struct BottomBar: View {
    enum Tab {
        case home
        case library
    }

    @Binding var selectedTab: Tab
    let onAdd: () -> Void

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, title: "Home", icon: "house.fill")

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(
                        LinearGradient(
                            colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                    .shadow(color: accent.opacity(0.38), radius: 18, y: 8)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Create a new study deck")

            tabButton(.library, title: "Library", icon: "book.pages.fill")
        }
        .padding(.horizontal, 26)
        .padding(.top, 12)
        .padding(.bottom, 0)
        .background(.black.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: Tab, title: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
            }
            .foregroundStyle(selectedTab == tab ? accent : .white.opacity(0.28))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
