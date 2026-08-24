import SwiftUI

struct DeckDetailsView: View {
    let deck: StudyDeck

    @State private var isShowingEditDeck = false
    @State private var isShowingEditCards = false

    @State private var isAnswerRevealed = false
    @State private var currentCardIndex = 0

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let cardFill = Color.white.opacity(0.18)

    private var totalCards: Int {
        deck.cards.filter { !$0.needsDeletion }.count
    }

    private var masteredCards: Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.correctCount > 0
        }.count
    }

    private var learningCards: Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.reviewCount > 0 &&
            $0.correctCount == 0
        }.count
    }

    private var newCards: Int {
        deck.cards.filter {
            !$0.needsDeletion &&
            $0.reviewCount == 0
        }.count
    }

    private var masteryProgress: Double {
        guard totalCards > 0 else { return 0 }

        return Double(masteredCards) / Double(totalCards)
    }

    private var availableCards: [StudyFlashcardCard] {
        deck.cards.filter { !$0.needsDeletion }
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {


                    VStack(spacing: 12) {

                        TabView(selection: $currentCardIndex) {
                            ForEach(
                                Array(availableCards.enumerated()),
                                id: \.element.persistentModelID
                            ) { index, card in

                                FlashcardView(
                                    card: card,
                                    isAnswerRevealed: isAnswerRevealed
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    revealAnswer()
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 315)

                        // Custom dots BELOW the flashcard
                        HStack(spacing: 6) {
                            ForEach(
                                0..<availableCards.count,
                                id: \.self
                            ) { index in

                                Capsule()
                                    .fill(
                                        index == currentCardIndex
                                            ? accent
                                            : .white.opacity(0.20)
                                    )
                                    .frame(
                                        width: index == currentCardIndex ? 18 : 6,
                                        height: 6
                                    )
                                    .animation(
                                        .easeInOut(duration: 0.2),
                                        value: currentCardIndex
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 20)
                    .onChange(of: currentCardIndex) {
                        isAnswerRevealed = false
                    }

                    VStack(alignment: .leading, spacing: 0) {


                        header
                            .padding(.top, 24)

                        masteryCard
                            .padding(.top, 28)

                        Text("Quick Actions")
                            .font(.custom("PlusJakartaSans-Bold", size: 20))
                            .foregroundStyle(.white)
                            .padding(.top, 32)

                        studyButton
                            .padding(.top, 16)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            actionCard(title: "Take Exam", subtitle: "Test yourself", icon: "doc.text.fill", color: .orange) { }
                            actionCard(
                                title: "Edit Cards",
                                subtitle: "Add, edit or delete cards",
                                icon: "rectangle.stack.fill",
                                color: accent
                            ) {
                                isShowingEditCards = true
                            }
                            actionCard(title: "View Analytics", subtitle: "Track progress", icon: "chart.bar.fill", color: .indigo) { }
                            actionCard(
                                title: "Edit Deck",
                                subtitle: "Modify title & details",
                                icon: "pencil",
                                color: .white.opacity(0.6)
                            ) {
                                isShowingEditDeck = true
                            }
                        }
                        .padding(.top, 16)
                        // .padding(.bottom, 40)

                        Text("Flashcards")
                            .font(.custom("PlusJakartaSans-Bold", size: 20))
                            .foregroundStyle(.white)
                            .padding(.top, 32)

                        flashcardList
                            .padding(.top, 16)
                    }
                    .padding(.horizontal, 20)

                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BackNavigationBar {
                    deckMoreOptionButton
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $isShowingEditDeck) {
            CreateOwnDeckView(existingDeck: deck)
        }
        .navigationDestination(isPresented: $isShowingEditCards) {
            AddFlashcardView(
                deck: deck,
                isEditMode: true
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {

                Text(deck.title)
                    .font(.custom("PlusJakartaSans-ExtraBold", size: 28))
                    .foregroundStyle(.white)

                if deck.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 14))
                }
            }

            HStack(spacing: 8) {
                
                Text(deck.subject.uppercased())
                    .font(.custom("PlusJakartaSans-Bold", size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent, in: Capsule())

                Text("\(deck.educationLevel) · \(deck.cards.count) card\(deck.cards.count == 1 ? "" : "s")")
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var deckMoreOptionButton: some View {

        Button {
            showDeckMoreOptions()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options for deck \(deck.title)")
        .disabled(deck.cards.isEmpty)
        .opacity(deck.cards.isEmpty ? 0.45 : 1)

    }

    private func showDeckMoreOptions() {
        let actionSheet = UIAlertController(title: "Deck Options", message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Edit Deck", style: .default) { _ in
            isShowingEditDeck = true
        })

        actionSheet.addAction(UIAlertAction(title: "Edit Cards", style: .default) { _ in
            isShowingEditCards = true
        })

        actionSheet.addAction(UIAlertAction(title: "Reset Progress", style: .destructive) { _ in
            // discardCreatedDeck()
        })

        actionSheet.addAction(UIAlertAction(title: "Delete Deck", style: .destructive) { _ in
            // discardCreatedDeck()
        })

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(actionSheet, animated: true)
        }
    }

    // MARK: Reveal

    private func revealAnswer() {
        guard !isAnswerRevealed else {
            withAnimation(.easeInOut(duration: 0.25)) {
                isAnswerRevealed = false
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            isAnswerRevealed = true
        }
    }
    
    private struct FlashcardView: View {
        let card: StudyFlashcardCard
        let isAnswerRevealed: Bool

        var body: some View {
            VStack(spacing: 0) {

                Text(card.front)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 22))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)


                if isAnswerRevealed {
                    Divider()
                        .overlay(.white.opacity(0.10))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 28)

                    Text(card.back)
                        .font(.custom("PlusJakartaSans-Regular", size: 17))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(
                            .opacity
                            .combined(with: .move(edge: .bottom))
                        )
                }

            }
            .frame(maxWidth: .infinity)
            .frame(height: 265)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .background(
                Color.white.opacity(0.055),
                in: RoundedRectangle(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        .white.opacity(0.16),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    
                } label: {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 24, weight: .medium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View card \(card.front) in deck")
                .padding(20)
            }
        }
    }

    private var masteryCard: some View {
        VStack(spacing: 20) {

            HStack(spacing: 24) {

                ZStack {

                    Circle()
                        .stroke(
                            .white.opacity(0.12),
                            lineWidth: 10
                        )

                    Circle()
                        .trim(
                            from: 0,
                            to: masteryProgress
                        )
                        .stroke(
                            accent,
                            style: StrokeStyle(
                                lineWidth: 10,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(masteryProgress * 100))%")
                            .font(
                                .custom(
                                    "PlusJakartaSans-Bold",
                                    size: 22
                                )
                            )
                            .foregroundStyle(.white)

                        Text("MASTERY")
                            .font(
                                .custom(
                                    "PlusJakartaSans-Regular",
                                    size: 10
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(0.5)
                            )
                    }
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 14) {

                    statRow(
                        label: "Total Cards",
                        value: "\(totalCards)"
                    )

                    statRow(
                        label: "Mastered",
                        value: "\(masteredCards)"
                    )

                    statRow(
                        label: "Learning",
                        value: "\(learningCards)"
                    )

                    statRow(
                        label: "New",
                        value: "\(newCards)"
                    )
                }
            }

            // Overall progress
            VStack(alignment: .leading, spacing: 8) {

                HStack {
                    Text("Progress")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(0.55)
                        )

                    Spacer()

                    Text("\(masteredCards) / \(totalCards)")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(accent)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {

                        Capsule()
                            .fill(.white.opacity(0.08))

                        Capsule()
                            .fill(accent)
                            .frame(
                                width: geometry.size.width
                                    * masteryProgress
                            )
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            cardFill,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    .white.opacity(0.28),
                    lineWidth: 1.5
                )
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                .foregroundStyle(.white)
        }
    }

    private var studyButton: some View {
        NavigationLink {
            StudyFlashcardsView(deck: deck)
        } label: {
            Label("Study Flashcards", systemImage: "play.fill")
                .font(.custom("PlusJakartaSans-SemiBold", size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [
                            accent,
                            Color(red: 0.55, green: 0.36, blue: 0.96)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18)
                )
        }
        .buttonStyle(.plain)
    }

    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))

                Text(title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.custom("PlusJakartaSans-Regular", size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.28), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var flashcardList: some View {
        VStack(spacing: 12) {

            ForEach(
                Array(
                    deck.cards
                        .filter { !$0.needsDeletion }
                        .enumerated()
                ),
                id: \.element.persistentModelID
            ) { index, card in

                flashcardRow(
                    number: index + 1,
                    card: card
                )
            }
        }
    }

    private func flashcardRow(
        number: Int,
        card: StudyFlashcardCard
    ) -> some View {

        HStack(spacing: 14) {

            Text(String(format: "%02d", number))
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.35)
                )
                .frame(width: 28)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(card.front)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(2)

                cardStatus(card)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    .white.opacity(0.25)
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            cardFill,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    .white.opacity(0.15),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private func cardStatus(
        _ card: StudyFlashcardCard
    ) -> some View {

        if card.reviewCount == 0 {

            Label("New", systemImage: "circle")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(
                    .white.opacity(0.4)
                )

        } else if card.interval < 7 {

            Label("Learning", systemImage: "arrow.triangle.2.circlepath")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(.orange)

        } else {

            Label("Mastered", systemImage: "checkmark.circle.fill")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 11
                    )
                )
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    let deck = StudyDeck(title: "Cell Division & Mitosis", subject: "Biology", educationLevel: "University")
    deck.cards = [StudyFlashcardCard(front: "What is mitosis?", back: "Cell division producing two identical cells")]
    return NavigationStack {
        DeckDetailsView(deck: deck)
    }
}
