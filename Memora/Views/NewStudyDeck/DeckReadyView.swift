//
//  DeckReadyView.swift
//  Memora
//
//  Created by fuckdazeshit on 16/08/26.
//

import SwiftUI

struct DeckReadyView: View {
    let deck: StudyDeck

    @State private var isShowingHome = false
    @State private var isShowingNewStudyDeck = false

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)

    private var firstCardPreview: String {
        deck.cards.first?.front ?? "No flashcards yet"
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(
                            LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .top, endPoint: .bottom),
                            in: Circle()
                        )
                        .padding(.top, 80)

                    Text("Your deck is ready!")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 32))
                        .foregroundStyle(.white)
                        .padding(.top, 28)

                    Text("Time to start learning")
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)

                    deckSummaryCard
                        .padding(.top, 48)

                    VStack(spacing: 12) {
                        AppButton(
                            title: "Start Studying",
                            background: AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing))
                        ) {
                            isShowingHome = true
                        }

                        AppButton(
                            title: "Create another deck",
                            foreground: .white.opacity(0.62),
                            background: AnyShapeStyle(.white.opacity(0.12))
                        ) {
                            isShowingNewStudyDeck = true
                        }
                    }
                    .padding(.top, 28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $isShowingHome) {
            HomeView()
        }
        .navigationDestination(isPresented: $isShowingNewStudyDeck) {
            NewStudyDeckView()
        }
    }

    private var deckSummaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(accent.opacity(0.35))
                    .frame(height: 52)
                    .padding(.leading, 14)
                    .padding(.top, 8)

                HStack(spacing: 12) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(accent, in: Circle())

                    Text(firstCardPreview)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 14)
                .frame(height: 60)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.75), in: Capsule())
            }

            Text(deck.title)
                .font(.custom("PlusJakartaSans-Bold", size: 22))
                .foregroundStyle(.white)
                .padding(.top, 4)

            HStack(spacing: 8) {
                Text(deck.subject)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(accent, in: Capsule())

                Text("·")
                    .foregroundStyle(.white.opacity(0.4))

                Text(deck.educationLevel)
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
                .padding(.top, 6)

            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.62))
                    Text("\(deck.cards.count) flashcard\(deck.cards.count == 1 ? "" : "s")")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "star")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.62))
                    Text("0% mastered")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.28), lineWidth: 1.5)
        }
    }
}

#Preview {
    let deck = StudyDeck(title: "Methaphetamine Formula", subject: "Chemistry", educationLevel: "High School")
    deck.cards = [
        StudyFlashcardCard(front: "What plants do when they consume sunlight", back: "Photosynthesis")
    ]
    return DeckReadyView(deck: deck)
}
