//
//  AddFlashcardView.swift
//  Memora
//
//  Created by fuckdazeshit on 15/08/26.
//

import SwiftUI
import PhotosUI

private struct Flashcard: Identifiable {
    let id = UUID()
    var front: String
    var back: String
    var frontImageData: Data?
    var backImageData: Data?
}

private enum CardSide {
    case front
    case back
}

struct AddFlashcardView: View {
    let deckTitle: String
    let subject: String
    let educationLevel: String

    @Environment(\.modelContext) private var modelContext
    @State private var cards: [Flashcard] = []
    @State private var frontText = ""
    @State private var backText = ""
    @State private var selectedSide: CardSide = .front
    @State private var editingCardID: Flashcard.ID?
    @State private var frontImageData: Data?
    @State private var backImageData: Data?
    @State private var frontImageItem: PhotosPickerItem?
    @State private var backImageItem: PhotosPickerItem?
    @State private var measuredEditorHeight: CGFloat = 0
    @State private var savedDeck: StudyDeck?
    @State private var isShowingDeckReady = false
    @FocusState private var isEditorFocused: Bool

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let minEditorHeight: CGFloat = 44

    private var editorHeight: CGFloat {
        max(minEditorHeight, measuredEditorHeight)
    }

    var body: some View {
        ZStack {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            BackButton()
                            Spacer()
                        }

                        AddFlashcardProgressIndicator(accent: accent)
                            .padding(.top, 32)

                        HStack(alignment: .top) {
                            Text("NEW STUDY DECK")
                                .font(.custom("PlusJakartaSans-Bold", size: 14))
                                .foregroundStyle(.white.opacity(0.62))

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 13))
                                Text("\(cards.count)")
                                    .font(.custom("PlusJakartaSans-Bold", size: 14))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.12), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(accent.opacity(0.5), lineWidth: 1.03)
                            }
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

                        addCardButton
                            .padding(.top, 24)

                        if !cards.isEmpty {
                            Text("Tap a card below to edit it")
                                .font(.custom("PlusJakartaSans-Regular", size: 13))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.top, 24)

                            VStack(spacing: 12) {
                                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
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
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .dismissKeyboardOnTap()
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                AppButton(
                    title: "Finish Deck · \(cards.count) card\(cards.count == 1 ? "" : "s")",
                    foreground: cards.isEmpty ? .white.opacity(0.45) : .white,
                    background: cards.isEmpty ? AnyShapeStyle(.white.opacity(0.16)) : AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing))
                ) {
                    finishDeck()
                }
                .disabled(cards.isEmpty)
                .padding(.horizontal, 20)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.black.opacity(0.92))
        }
        .navigationDestination(isPresented: $isShowingDeckReady) {
            if let savedDeck {
                DeckReadyView(deck: savedDeck)
            }
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

    private var addCardButton: some View {
        Button(action: saveCard) {
            Label(editingCardID == nil ? "Add Card" : "Save Card", systemImage: "plus")
                .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.28), lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }

    private func flashcardRow(index: Int, card: Flashcard) -> some View {
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

    private func saveCard() {
        if let editingCardID, let index = cards.firstIndex(where: { $0.id == editingCardID }) {
            cards[index] = Flashcard(front: frontText, back: backText, frontImageData: frontImageData, backImageData: backImageData)
        } else {
            cards.append(Flashcard(front: frontText, back: backText, frontImageData: frontImageData, backImageData: backImageData))
        }

        frontText = ""
        backText = ""
        frontImageData = nil
        backImageData = nil
        frontImageItem = nil
        backImageItem = nil
        editingCardID = nil
        selectedSide = .front
    }

    private func editCard(_ card: Flashcard) {
        editingCardID = card.id
        frontText = card.front
        backText = card.back
        frontImageData = card.frontImageData
        backImageData = card.backImageData
        selectedSide = .front
    }

    private func deleteCard(_ card: Flashcard) {
        cards.removeAll { $0.id == card.id }
        if editingCardID == card.id {
            editingCardID = nil
            frontText = ""
            backText = ""
            frontImageData = nil
            backImageData = nil
        }
    }

    private func finishDeck() {
        let deck = StudyDeck(title: deckTitle, subject: subject, educationLevel: educationLevel)
        deck.cards = cards.map {
            StudyFlashcardCard(front: $0.front, back: $0.back, frontImageData: $0.frontImageData, backImageData: $0.backImageData)
        }
        modelContext.insert(deck)
        try? modelContext.save()
        savedDeck = deck
        isShowingDeckReady = true
    }
}

private struct EditorHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AddFlashcardProgressIndicator: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { step in
                Capsule()
                    .fill(step == 2 ? accent : .white.opacity(0.12))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step 3 of 3")
    }
}

#Preview {
    AddFlashcardView(deckTitle: "Methaphetamine Formula", subject: "Chemistry", educationLevel: "High School")
}
