//
//  AddFlashcardView.swift
//  Memora
//
//  Created by fuckdazeshit on 15/08/26.
//

import SwiftUI
import PhotosUI

private enum CardSide {
    case front
    case back
}

struct AddFlashcardView: View {

    let deck: StudyDeck
    let isEditMode: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var frontText = ""
    @State private var backText = ""

    @State private var selectedSide: CardSide = .front

    @State private var editingCardID: UUID?

    @State private var frontImageData: Data?
    @State private var backImageData: Data?

    @State private var frontImageItem: PhotosPickerItem?
    @State private var backImageItem: PhotosPickerItem?

    @State private var measuredEditorHeight: CGFloat = 0

    @State private var isShowingCardList = false

    @FocusState private var isEditorFocused: Bool

    let onFinish: (() -> Void)?

    private let accent = Color(
        red: 0.39,
        green: 0.40,
        blue: 0.95
    )

    private let minEditorHeight: CGFloat = 44

    private var editorHeight: CGFloat {
        max(minEditorHeight, measuredEditorHeight)
    }

    init(
        deck: StudyDeck,
        isEditMode: Bool = false,
        onFinish: (() -> Void)? = nil
    ) {
        self.deck = deck
        self.isEditMode = isEditMode
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        HStack {
                            Text(deck.subject.uppercased())
                                .font(.custom("PlusJakartaSans-Bold", size: 11))
                                .tracking(0.5)
                                .foregroundStyle(accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    accent.opacity(0.12),
                                    in: Capsule()
                                )

                            Spacer()

                            Button {
                                isShowingCardList = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .font(.system(size: 13))

                                    Text("\(deck.cards.filter { !$0.needsDeletion }.count)")
                                        .font(.custom("PlusJakartaSans-Bold", size: 14))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    .white.opacity(0.12),
                                    in: Capsule()
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(accent.opacity(0.5), lineWidth: 1.03)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(deck.cards.isEmpty)
                            .opacity(deck.cards.isEmpty ? 0.5 : 1)
                        }
                        .padding(.top, 16)

                        Text("Add flashcards")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)

                        Text("Write the question and its answer")
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 20)

                        sideSwitcher
                            .padding(.top, 30)

                        cardEditor
                            .padding(.top, 12)

                        if !deck.cards.isEmpty {
                            Text("Tap a card below to edit it")
                                .font(.custom("PlusJakartaSans-Regular", size: 13))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.top, 24)

                            VStack(spacing: 12) {
                                ForEach(
                                    Array(
                                        deck.cards
                                            .filter { !$0.needsDeletion }
                                            .enumerated()
                                    ),
                                    id: \.element.id
                                ) { index, card in
                                    flashcardRow(index: index, card: card)
                                }
                            }
                            .padding(.top, 10)
                        }

                        Color.clear
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    BackNavigationBar {
                        finishDeckButton
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .dismissKeyboardOnTap()
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {

            VStack(spacing: 12) {

                if !isEditMode {
                    WorkflowIndicator(
                        numberOfSteps: 3,
                        currentStep: 2,
                        accent: accent
                    )
                    .padding(.horizontal, 20)
                }

                cardActionButtons
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.black.opacity(0.92))
        }
    }

    private var sideSwitcher: some View {
        HStack(spacing: 4) {
            sideButton(title: "Front", side: .front)
            sideButton(title: "Back", side: .back)
        }
        .padding(4)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sideButton(title: String, side: CardSide) -> some View {
        Button {
            selectedSide = side
        } label: {
            Text(title)
                .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                .foregroundStyle(selectedSide == side ? .black : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
                .background(selectedSide == side ? .white : .clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var cardEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedSide == .front ? "FRONT" : "BACK")
                    .font(.custom("PlusJakartaSans-Bold", size: 13))
                    .foregroundStyle(accent)

                Spacer()

                Button {
                    // Preview flashcard — coming soon.
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accent)
                        .frame(width: 36, height: 36)
                        .background(accent.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .topLeading) {
                if activeText.isEmpty {
                    Text(selectedSide == .front ? "Question or term..." : "Answer or definition...")
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }

                // Invisible sizer mirroring the text so the editor grows with its content.
                Text(activeText.isEmpty ? " " : activeText)
                    .font(.custom("PlusJakartaSans-Regular", size: 16))
                    .foregroundColor(.clear)
                    .padding(.top, 8)
                    .padding(.horizontal, 5)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: EditorHeightPreferenceKey.self, value: geometry.size.height)
                        }
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                TextEditor(text: activeTextBinding)
                    .font(.custom("PlusJakartaSans-Regular", size: 16))
                    .foregroundStyle(.white)
                    .tint(accent)
                    .focused($isEditorFocused)
                    .scrollContentBackground(.hidden)
            }
            .frame(height: editorHeight)
            .onPreferenceChange(EditorHeightPreferenceKey.self) { measuredEditorHeight = $0 }

            if let activeImageData, let uiImage = UIImage(data: activeImageData) {
                HStack {
                    Spacer()

                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                removeAttachedImage()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(.black.opacity(0.55), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }

                    Spacer()
                }
            }

            HStack {
                Spacer()

                PhotosPicker(selection: activeImageItemBinding, matching: .images) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.12), in: Circle())
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.28), lineWidth: 1.5)
        }
        .onChange(of: frontImageItem) { _, newItem in
            loadImage(from: newItem) { data in frontImageData = data }
        }
        .onChange(of: backImageItem) { _, newItem in
            loadImage(from: newItem) { data in backImageData = data }
        }
    }

    private var cardActionButtons: some View {

        let hasContent =
            !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Group {

            if editingCardID != nil {

                HStack(spacing: 12) {

                    AppButton(
                        title: "Edit Card",
                        icon: .sf("checkmark"),
                        background: LinearGradient(
                            colors: [
                                accent,
                                Color(red: 0.55, green: 0.36, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    ) {
                        updateCard()
                    }

                    Button {
                        deleteEditingCard()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 58, height: 56)
                            .background(
                                .red.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        .red.opacity(0.25),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }.padding(.horizontal, 20)

            } else {
                HStack {
                    Button {
                        addCard()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")

                            Text("Add Card")
                                .font(
                                    .custom(
                                        "PlusJakartaSans-SemiBold",
                                        size: 16
                                    )
                                )
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    accent,
                                    Color(red: 0.55, green: 0.36, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasContent)
                    .opacity(hasContent ? 1 : 0.45)
                }.padding(.horizontal, 20)
            }
        }
    }

    private var activeText: String {
        selectedSide == .front ? frontText : backText
    }

    private var activeTextBinding: Binding<String> {
        selectedSide == .front ? $frontText : $backText
    }

    private var activeImageData: Data? {
        selectedSide == .front ? frontImageData : backImageData
    }

    private var activeImageItemBinding: Binding<PhotosPickerItem?> {
        selectedSide == .front ? $frontImageItem : $backImageItem
    }

    private func removeAttachedImage() {
        switch selectedSide {
        case .front:
            frontImageData = nil
            frontImageItem = nil
        case .back:
            backImageData = nil
            backImageItem = nil
        }
    }

    private func loadImage(from item: PhotosPickerItem?, completion: @escaping (Data?) -> Void) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                completion(data)
            }
        }
    }

    private func addCard() {

        let card = StudyFlashcardCard(
            front: frontText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            back: backText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            frontImageData: frontImageData,
            backImageData: backImageData
        )

        card.isSynced = false
        card.syncState = SyncManager.CardSyncState.created

        deck.cards.append(card)

        do {
            try modelContext.save()

            print("")
            print("========== CARD CREATED LOCALLY ==========")
            print("DECK:", deck.id)
            print("CARD:", card.id)
            print("FRONT:", card.front)
            print("SYNC STATE:", card.syncState)
            print("SYNCED:", card.isSynced)

            resetEditor()

        } catch {
            print("❌ CREATE CARD ERROR:", error)
        }
    }

    private func updateCard() {

        guard let editingCardID,
            let card = deck.cards.first(
                where: { $0.id == editingCardID }
            )
        else {
            return
        }

        card.front = frontText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        card.back = backText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        card.frontImageData = frontImageData
        card.backImageData = backImageData

        card.isSynced = false
        card.syncState = SyncManager.CardSyncState.updated

        do {
            try modelContext.save()

            print("")
            print("========== CARD UPDATED LOCALLY ==========")
            print("ID:", card.id)
            print("FRONT:", card.front)
            print("BACK:", card.back)
            print("SYNC STATE:", card.syncState)
            print("SYNCED:", card.isSynced)

            resetEditor()

        } catch {
            print("❌ UPDATE CARD ERROR:", error)
        }
    }

    private func resetEditor() {

        frontText = ""
        backText = ""

        frontImageData = nil
        backImageData = nil

        frontImageItem = nil
        backImageItem = nil

        editingCardID = nil
        selectedSide = .front

        measuredEditorHeight = 0

        isEditorFocused = false
    }

    private func editCard(_ card: StudyFlashcardCard) {

        editingCardID = card.id

        frontText = card.front
        backText = card.back

        frontImageData = card.frontImageData
        backImageData = card.backImageData

        selectedSide = .front
    }

    private func deleteCard(_ card: StudyFlashcardCard) {

        card.needsDeletion = true
        card.isSynced = false
        card.syncState = SyncManager.CardSyncState.deleted

        do {
            try modelContext.save()

            print("")
            print("========== CARD MARKED FOR DELETION ==========")
            print("ID:", card.id)
            print("FRONT:", card.front)
            print("NEEDS DELETION:", card.needsDeletion)
            print("SYNC STATE:", card.syncState)
            print("SYNCED:", card.isSynced)

            if editingCardID == card.id {
                resetEditor()
            }

        } catch {
            print("❌ DELETE CARD ERROR:", error)
        }
    }

    private func deleteEditingCard() {

        guard let editingCardID,
            let card = deck.cards.first(
                where: { $0.id == editingCardID }
            )
        else {
            return
        }

        card.needsDeletion = true
        card.isSynced = false
        card.syncState = SyncManager.CardSyncState.deleted

        do {
            try modelContext.save()

            print("")
            print("========== CARD MARKED FOR DELETION ==========")
            print("ID:", card.id)
            print("FRONT:", card.front)
            print("NEEDS DELETION:", card.needsDeletion)
            print("SYNC STATE:", card.syncState)
            print("SYNCED:", card.isSynced)

            resetEditor()

        } catch {
            print("❌ DELETE CARD ERROR:", error)
        }
    }

    private func finishDeck() {

        do {
            try modelContext.save()

            print("")
            print("========== FINISH DECK ==========")
            print("DECK:", deck.id)
            print(
                "ACTIVE CARDS:",
                deck.cards.filter { !$0.needsDeletion }.count
            )

            if isEditMode {
                print("✅ EDIT SAVED LOCALLY")
                dismiss()
            } else {
                print("✅ NEW DECK SAVED LOCALLY")
                onFinish?()
            }

        } catch {
            print("❌ FINISH DECK ERROR:", error)
        }
    }

    private var finishDeckButton: some View {

        Button {
            finishDeck()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 40, height: 40)
                .background(
                LinearGradient(
                    colors: [
                        accent,
                        Color(red: 0.55, green: 0.36, blue: 0.96)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done adding flashcards")
        .disabled(deck.cards.isEmpty)
        .opacity(deck.cards.isEmpty ? 0.45 : 1)

    }

    private func flashcardRow(index: Int, card: StudyFlashcardCard) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                editCard(card)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.custom("PlusJakartaSans-Bold", size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(accent, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.front)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(card.back)
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer(minLength: 30)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.28), lineWidth: 1.5)
                }
            }
            .buttonStyle(.plain)

            Button {
                deleteCard(card)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
}

private struct EditorHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    Text("AddFlashcardView Preview")
}