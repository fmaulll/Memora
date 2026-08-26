import SwiftUI

struct DeckOptionsSheet: View {
    let deck: StudyDeck
    let isParentDeck: Bool
    let canCreateSubDeck: Bool

    let onEditDeck: () -> Void
    let onCreateSubDeck: () -> Void
    let onMoveDeck: () -> Void
    let onManageCards: () -> Void
    let onResetProgress: () -> Void
    let onDeleteDeck: () -> Void

    private let accent = Color(
        red: 0.40,
        green: 0.40,
        blue: 0.95
    )

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    optionButton(
                        title: "Edit Deck",
                        icon: "pencil",
                        action: onEditDeck
                    )
                    .padding(.top, 20)

                    if canCreateSubDeck {
                        optionButton(
                            title: "Create Sub-deck",
                            icon: "folder.badge.plus",
                            action: onCreateSubDeck
                        )
                    }

                    optionButton(
                        title: "Move Deck",
                        icon: "folder",
                        action: onMoveDeck
                    )

                    if canCreateSubDeck {
                        optionButton(
                            title: "Manage Cards",
                            icon: "rectangle.stack",
                            action: onManageCards
                        )
                    }

                    optionButton(
                        title: "Reset Progress",
                        icon: "arrow.counterclockwise",
                        action: onResetProgress
                    )

                    optionButton(
                        title: "Delete Deck",
                        icon: "trash",
                        destructive: true,
                        action: onDeleteDeck
                    )
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(
                red: 0.035,
                green: 0.035,
                blue: 0.16
            )
        )
        .preferredColorScheme(.dark)
    }

    private func optionButton(
        title: String,
        icon: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 34)

                Text(title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 14
                        )
                    )

                Spacer()
            }
            .foregroundStyle(
                destructive
                    ? Color.red.opacity(0.9)
                    : .white.opacity(0.88)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}