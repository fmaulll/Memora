import SwiftUI

struct DeckOptionsSheet: View {
    let deck: StudyDeck
    let isParentDeck: Bool
    let canCreateSubDeck: Bool
    let canCreateWithAI: Bool
    let aiDeckAction: AIDeckAction?

    let onEditDeck: () -> Void
    let onCreateSubDeck: () -> Void
    let onCreateWithAI: () -> Void
    let onMoveDeck: () -> Void
    let onManageCards: () -> Void
    let onResetProgress: () -> Void
    let onDeleteDeck: () -> Void
    let onGenerateCardsWithAI: () -> Void
    let onGenerateMoreCardsWithAI: () -> Void
    

    private let accent = Color.appAccent

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {

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
                    
                    if let aiDeckAction {
                        switch aiDeckAction {

                        case .createDeck:
                            optionButton(
                                title: "Create with AI",
                                icon: "sparkles",
                                action: onCreateWithAI
                            )

                        case .generateCards:
                            optionButton(
                                title: "Generate Cards with AI",
                                icon: "sparkles",
                                action: onGenerateCardsWithAI
                            )

                        case .generateMoreCards:
                            optionButton(
                                title: "Generate More Cards",
                                icon: "sparkles",
                                action: onGenerateMoreCardsWithAI
                            )
                        }
                    }

                    optionButton(
                        title: "Move Deck",
                        icon: "folder",
                        action: onMoveDeck
                    )

                    if !isParentDeck {
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
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
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
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(
                        destructive
                            ? Color.appSecondarySurface
                            : Color.appSurface,
                        in: RoundedRectangle(cornerRadius: 8)
                    )

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
                    ? Color.appError
                    : Color.appTextPrimary
            )
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
            .background(
                destructive
                    ? Color.appSecondarySurface
                    : Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        destructive ? Color.appError : Color.appBorder,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}