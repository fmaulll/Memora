import SwiftUI

struct DeckOptionsSheet: View {
    let deck: StudyDeck
    let isParentDeck: Bool
    let canCreateSubDeck: Bool
    let canCreateWithAI: Bool
    let selectedChapter: StudyDeck?
    let aiDeckAction: AIDeckAction?

    let onEditDeck: () -> Void
    let onEditChapter: () -> Void
    let onCreateSubDeck: () -> Void
    let onMoveChapter: () -> Void
    let onReorderChapter: () -> Void
    let onResetChapterProgress: () -> Void
    let onDeleteChapter: () -> Void
    let onCreateWithAI: () -> Void
    let onMoveDeck: () -> Void
    let onManageCards: () -> Void
    let onResetProgress: () -> Void
    let onDeleteDeck: () -> Void
    let onGenerateCardsWithAI: () -> Void
    let onGenerateMoreCardsWithAI: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {

                    // MARK: - Deck

                    sectionLabel("Deck")
                        .padding(.top, 8)

                    optionButton(
                        title: "Edit Deck",
                        icon: "pencil",
                        action: onEditDeck
                    )

                    // Standalone decks can be moved.
                    // Parent decks stay as the container for their chapters.
                    if !isParentDeck {
                        optionButton(
                            title: "Move Deck",
                            icon: "folder",
                            action: onMoveDeck
                        )
                    }

                    // Standalone deck owns its cards directly.
                    if !isParentDeck {
                        optionButton(
                            title: "Manage Cards",
                            icon: "rectangle.stack",
                            action: onManageCards
                        )
                    }

                    optionButton(
                        title: "Reset Deck Progress",
                        icon: "arrow.counterclockwise",
                        action: onResetProgress
                    )

                    optionButton(
                        title: "Delete Deck",
                        icon: "trash",
                        destructive: true,
                        action: onDeleteDeck
                    )

                    // MARK: - Chapters

                    if isParentDeck {
                        sectionLabel("Chapters")

                        if canCreateSubDeck {
                            optionButton(
                                title: "Create Chapter",
                                icon: "folder.badge.plus",
                                action: onCreateSubDeck
                            )
                        }

                        if selectedChapter != nil {
                            optionButton(
                                title: "Edit Chapter",
                                icon: "pencil",
                                action: onEditChapter
                            )

                            optionButton(
                                title: "Move Chapter",
                                icon: "folder",
                                action: onMoveChapter
                            )

                            optionButton(
                                title: "Reorder Chapter",
                                icon: "arrow.up.arrow.down",
                                action: onReorderChapter
                            )

                            optionButton(
                                title: "Manage Cards",
                                icon: "rectangle.stack",
                                action: onManageCards
                            )

                            optionButton(
                                title: "Reset Chapter Progress",
                                icon: "arrow.counterclockwise",
                                action: onResetChapterProgress
                            )

                            optionButton(
                                title: "Delete Chapter",
                                icon: "trash",
                                destructive: true,
                                action: onDeleteChapter
                            )
                        }
                    }

                    // MARK: - AI
                    // Temporarily disabled.
                    /*
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
                    */
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(
                .custom(
                    "PlusJakartaSans-SemiBold",
                    size: 11
                )
            )
            .foregroundStyle(Color.appTextSecondary)
            .tracking(0.8)
            .padding(.horizontal, 4)
            .padding(.top, 12)
            .padding(.bottom, 2)
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
                        destructive
                            ? Color.appError
                            : Color.appBorder,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}