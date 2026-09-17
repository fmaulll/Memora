//
//  CreateOwnDeckView.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
//

import SwiftUI
import SwiftData

enum CreateDeckMode {
    case withCards
    case empty
}

struct CreateOwnDeckView: View {
    let existingDeck: StudyDeck?
    let mode: CreateDeckMode
    let parentDeck: StudyDeck?
    let onFinish: ((StudyDeck) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var createdDeck: StudyDeck?
    @State private var deckTitle: String
    @State private var subject: String
    @State private var educationLevel: String
    @State private var isShowingAddFlashcards = false
    @State private var isShowingDiscardConfirmation = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case deckTitle
        case subject
        case educationLevel
    }

    private let accent = Color.appAccent

    private let educationLevels = [
        "Elementary School",
        "Middle School",
        "High School",
        "University",
        "Professional",
        "Self-taught",
    ]

    init(
        existingDeck: StudyDeck? = nil,
        mode: CreateDeckMode = .withCards,
        parentDeck: StudyDeck? = nil,
        onFinish: ((StudyDeck) -> Void)? = nil
    ) {
        self.existingDeck = existingDeck
        self.onFinish = onFinish
        self.parentDeck = parentDeck
        self.mode = mode    

        _deckTitle = State(initialValue: existingDeck?.title ?? "")
        _subject = State(initialValue: existingDeck?.subject ?? "")
        _educationLevel = State(
            initialValue: existingDeck?.educationLevel ?? ""
        )
    }

    private var isEditMode: Bool {
        existingDeck != nil
    }

    private var canContinue: Bool {
        !deckTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        &&
        (
            mode == .empty
            ||
            !subject
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
        &&
        (
            mode == .empty
            ||
            !educationLevel
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        )
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {
                    header

                    if let parentDeck {
                        parentDeckPreview(parentDeck)
                    }

                    deckTitleSection

                    if mode == .withCards &&
                        parentDeck == nil {

                        subjectSection
                        educationLevelSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .safeAreaInset(
            edge: .top,
            spacing: 0
        ) {
            BackNavigationBar(
                onBack: handleBack
            ) {
                EmptyView()
            }
        }
        .safeAreaInset(
            edge: .bottom,
            spacing: 0
        ) {
            bottomActionBar
        }
        .navigationDestination(
            isPresented: $isShowingAddFlashcards
        ) {
            if let createdDeck {
                AddFlashcardView(
                    deck: createdDeck,
                    isEditMode: false,
                    onFinish: {
                        isShowingAddFlashcards = false
                        onFinish?(createdDeck)
                    }
                )
            }
        }
        .alert(
            "Discard Deck?",
            isPresented: $isShowingDiscardConfirmation
        ) {
            Button(
                "Discard",
                role: .destructive
            ) {
                discardCreatedDeck()
            }

            Button(
                "Keep Editing",
                role: .cancel
            ) {}
        } message: {
            Text(
                "Your deck and cards haven't been finished yet. "
                + "If you discard it, all of your progress will be lost."
            )
        }
    }

    private var headerEyebrow: String {
    if isEditMode {
        return "EDIT DECK"
    }

    if parentDeck != nil {
        return "CREATE CHAPTER"
    }

    return "CREATE MANUALLY"
}

    private var headerTitle: String {
        if isEditMode {
            return "Edit your\ndeck"
        }

        if parentDeck != nil {
            return "Create a new\nchapter"
        }

        return "What do you want\nto study?"
    }

    private var headerDescription: String {
        if isEditMode {
            return "Update your deck details."
        }

        if parentDeck != nil {
            return "Add a focused chapter to organize this deck."
        }

        if mode == .empty {
            return "Create an empty deck, then add chapters or cards whenever you're ready."
        }

        return "Create your own deck and write the flashcards yourself."
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            Text(headerEyebrow)
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(accent)

            Text(headerTitle)
                .font(
                    .custom(
                        "PlusJakartaSans-ExtraBold",
                        size: 38
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .tracking(-1)
                .lineSpacing(-3)

            Text(headerDescription)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 14
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
                .lineSpacing(4)
        }
    }

    private func parentDeckPreview(_ parentDeck: StudyDeck) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PARENT DECK")
                .font(.custom("PlusJakartaSans-Bold", size: 11))
                .foregroundStyle(Color.appTextSecondary)

            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)

                Text(parentDeck.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
    }

    // MARK: - Bottom Action

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            AppButton(
                title: actionButtonTitle,
                foreground:
                    canContinue
                        ? Color.appTextPrimary
                        : Color.appTextSecondary
            ) {
                if isEditMode {
                    saveDeck()
                } else {
                    continueToCards()
                }
            }
            .disabled(!canContinue)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(height: 1)
        }
    }

    private var actionButtonTitle: String {
        if isEditMode {
            return "Save Changes"
        }

        if parentDeck != nil {
            return "Create Chapter"
        }

        if mode == .empty {
            return "Create Deck"
        }

        return "Continue"
    }

    private func fieldTitle(
        _ title: String,
        isFocused: Bool
    ) -> some View {
        Text(title)
            .font(
                .custom(
                    "PlusJakartaSans-SemiBold",
                    size: 13
                )
            )
            .foregroundStyle(
                isFocused
                    ? Color.appTextPrimary
                    : Color.appTextSecondary
            )
    }

    // MARK: - Deck Title

    private var deckTitleSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldTitle(
                "Deck title",
                isFocused: focusedField == .deckTitle
            )

            HStack(spacing: 12) {
                Image(systemName: "rectangle.stack")
                    .font(
                        .system(
                            size: 16,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        focusedField == .deckTitle
                            ? accent
                            : Color.appTextSecondary
                    )
                    .frame(width: 20)

                TextField(
                    parentDeck != nil
                        ? "e.g. Cell Biology"
                        : "e.g. Spanish Vocabulary",
                    text: $deckTitle
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 15
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .tint(accent)
                .textInputAutocapitalization(.sentences)
                .focused(
                    $focusedField,
                    equals: .deckTitle
                )
                .submitLabel(
                    mode == .withCards &&
                    parentDeck == nil
                        ? .next
                        : .done
                )

                if !deckTitle.isEmpty {
                    Button {
                        deckTitle = ""
                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .font(.system(size: 16))
                        .foregroundStyle(
                            Color.appTextSecondary
                                .opacity(0.6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        focusedField == .deckTitle
                            ? accent
                            : Color.appBorder,
                        lineWidth:
                            focusedField == .deckTitle
                                ? 1.5
                                : 1
                    )
            }
            .animation(
                .easeInOut(duration: 0.15),
                value: focusedField
            )
        }
    }

    // MARK: - Subject

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldTitle(
                "Subject",
                isFocused: focusedField == .subject
            )

            HStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .font(
                        .system(
                            size: 16,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        focusedField == .subject
                            ? accent
                            : Color.appTextSecondary
                    )
                    .frame(width: 20)

                TextField(
                    "e.g. Biology, Physics, History",
                    text: $subject
                )
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 15
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .tint(accent)
                .textInputAutocapitalization(.sentences)
                .focused(
                    $focusedField,
                    equals: .subject
                )
                .submitLabel(.done)

                if !subject.isEmpty {
                    Button {
                        subject = ""
                    } label: {
                        Image(
                            systemName:
                                "xmark.circle.fill"
                        )
                        .font(.system(size: 16))
                        .foregroundStyle(
                            Color.appTextSecondary
                                .opacity(0.6)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(
                Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        focusedField == .subject
                            ? accent
                            : Color.appBorder,
                        lineWidth:
                            focusedField == .subject
                                ? 1.5
                                : 1
                    )
            }
            .animation(
                .easeInOut(duration: 0.15),
                value: focusedField
            )
        }
    }

    private var educationLevelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EDUCATION LEVEL")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 11
                    )
                )
                .foregroundStyle(Color.appTextSecondary)

            Menu {
                ForEach(educationLevels, id: \.self) { level in
                    Button {
                        educationLevel = level
                    } label: {
                        Text(level)
                    }
                }
            } label: {
                HStack {
                    Text(
                        educationLevel.isEmpty
                            ? "Select education level"
                            : educationLevel
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 16
                        )
                    )
                    .foregroundStyle(
                        educationLevel.isEmpty
                            ? Color.appTextSecondary
                            : Color.appTextPrimary
                    )

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    Color.appSurface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBorder, lineWidth: 1)
                }
            }
        }
    }

    private func handleBack() {

        // Editing an existing deck:
        // just leave the screen normally.
        if isEditMode {
            dismiss()
            return
        }

        // Creating a new deck:
        // if the deck hasn't been created yet, leave normally.
        guard createdDeck != nil else {
            dismiss()
            return
        }

        // A deck was already created locally.
        // Ask the user whether they want to discard it.
        isShowingDiscardConfirmation = true
    }

    private func discardCreatedDeck() {

        guard let createdDeck else {
            dismiss()
            return
        }

        print("")
        print("========== DISCARDING DECK ==========")
        print("DECK:", createdDeck.id)
        print("TITLE:", createdDeck.title)
        print("CARDS:", createdDeck.cards.count)

        // Delete all cards belonging to this unfinished deck.
        for card in createdDeck.cards {
            modelContext.delete(card)
        }

        // Delete the deck itself.
        modelContext.delete(createdDeck)

        do {
            try modelContext.save()

            print("✅ DECK AND CARDS DISCARDED")

            dismiss()

        } catch {
            print("❌ FAILED TO DISCARD DECK:", error)
        }
    }

    private func saveDeck() {

        guard let existingDeck else {
            return
        }

        existingDeck.title = deckTitle.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        existingDeck.subject = subject.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        existingDeck.educationLevel = educationLevel.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        existingDeck.isSynced = false

        do {
            try modelContext.save()

            print("")
            print("========== DECK UPDATED LOCALLY ==========")
            print("ID:", existingDeck.id)
            print("TITLE:", existingDeck.title)
            print("SUBJECT:", existingDeck.subject)
            print("EDUCATION:", existingDeck.educationLevel)
            print("SYNCED:", existingDeck.isSynced)

            dismiss()

            Task {
                do {
                    try await SyncManager.shared.sync(
                        modelContext: modelContext
                    )

                    print("✅ DECK UPDATE SYNC SUCCESS")

                } catch {
                    print("⚠️ DECK UPDATE SYNC FAILED:", error)
                }
            }

        } catch {
            print("❌ UPDATE DECK ERROR:", error)
        }
    }

    private func continueToCards() {

        // We already created a deck earlier in this creation flow.
        // Reuse it instead of creating another one.
        if createdDeck != nil {
            isShowingAddFlashcards = true
            return
        }

        let deck = StudyDeck(
            title: deckTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: mode == .withCards
                ? subject.trimmingCharacters(in: .whitespacesAndNewlines)
                : parentDeck?.subject ?? "General",
            educationLevel: mode == .withCards
                ? educationLevel.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                : parentDeck?.educationLevel ?? "Self-Study"
        )

        deck.parentDeck = parentDeck
        deck.isSynced = false

        modelContext.insert(deck)

        do {
            try modelContext.save()

            print("")
            print("========== DECK CREATED LOCALLY ==========")
            print("ID:", deck.id)
            print("TITLE:", deck.title)
            print("SUBJECT:", deck.subject)
            print("SYNCED:", deck.isSynced)

            createdDeck = deck

            switch mode {
            case .withCards:
                isShowingAddFlashcards = true

            case .empty:
                onFinish?(deck)
            }

        } catch {
            print("❌ CREATE DECK ERROR:", error)
        }
    }

}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    // MARK: - Deck Creation

    
}

#Preview {
    CreateOwnDeckView()
}
