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

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

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
        ZStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        Text(headerEyebrow)
                            .font(.custom("PlusJakartaSans-Bold", size: 14))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 16)

                        Text(headerTitle)
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)

                        Text(headerDescription)
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 20)

                        if let parentDeck {
                            parentDeckPreview(parentDeck)
                                .padding(.top, 30)
                        }

                        formField(
                            label: "DECK TITLE",
                            placeholder: "e.g. Spanish Vocabulary — Beginner",
                            text: $deckTitle,
                            field: .deckTitle
                        )
                        .padding(.top, parentDeck != nil ? 24 : 30)

                        if mode == .withCards && parentDeck == nil {

                            formField(
                                label: "SUBJECT",
                                placeholder: "e.g. Biology, Physics, History",
                                text: $subject,
                                field: .subject
                            )
                            .padding(.top, 24)

                            formField(
                                label: "EDUCATION LEVEL",
                                placeholder: "e.g. University, High School, Self-Study",
                                text: $educationLevel,
                                field: .educationLevel
                            )
                            .padding(.top, 24)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    BackNavigationBar(
                        onBack: handleBack
                    ) {
                        EmptyView()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .dismissKeyboardOnTap()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                if !isEditMode && (mode == .withCards || mode == .empty && parentDeck == nil) {
                    WorkflowIndicator(
                        numberOfSteps: mode == .empty ? 2 : 3,
                        currentStep: 1,
                        accent: accent
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                HStack {
                    AppButton(
                        title: isEditMode
                            ? "Save Deck"
                            : mode == .empty
                                ? (parentDeck != nil ? "Create Sub-deck" : "Create Deck")
                                : "Continue",
                        foreground: canContinue ? .white : .white.opacity(0.45),
                        background: AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing))
                    ) {
                        if isEditMode {
                            saveDeck()
                        } else {
                            continueToCards()
                        }
                    }
                    .disabled(!canContinue)
                    .padding(.horizontal, 20)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.black.opacity(0.92))
        }
        .navigationDestination(isPresented: $isShowingAddFlashcards) {
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
            Button("Discard", role: .destructive) {
                discardCreatedDeck()
            }

            Button("Keep Editing", role: .cancel) {
                // Do nothing.
            }
        } message: {
            Text(
                "Your deck and cards haven't been finished yet. "
                + "If you discard it, all of your progress will be lost."
            )
        }
    }

    private var headerEyebrow: String {
        if isEditMode {
            return "EDIT STUDY DECK"
        }

        if parentDeck != nil {
            return "CREATE SUB-DECK"
        }

        if mode == .empty {
            return "CREATE EMPTY DECK"
        }

        return "NEW STUDY DECK"
    }

    private var headerTitle: String {
        if isEditMode {
            return "Edit your deck"
        }

        if parentDeck != nil {
            return "Add a section"
        }

        if mode == .empty {
            return "Create your deck"
        }

        return "What do you want\nto learn?"
    }

    private var headerDescription: String {
        if isEditMode {
            return "Update your deck details"
        }

        if parentDeck != nil {
            return "Organize this deck into a focused study topic."
        }

        if mode == .empty {
            return "Add cards or sub-decks whenever you're ready."
        }

        return "Be specific for better flashcards"
    }

    private func parentDeckPreview(_ parentDeck: StudyDeck) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PARENT DECK")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.62))

            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)

                Text(parentDeck.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                .white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            }
        }
    }

    private func formField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(label)
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 14
                    )
                )
                .foregroundStyle(.white.opacity(0.62))

            TextField(
                placeholder,
                text: text
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 16
                )
            )
            .foregroundStyle(.white)
            .tint(accent)
            .focused(
                $focusedField,
                equals: field
            )
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
            .background(
                .white.opacity(0.18),
                in: RoundedRectangle(
                    cornerRadius: 12
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 12
                )
                .stroke(
                    .white.opacity(0.28),
                    lineWidth: 1.03
                )
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
