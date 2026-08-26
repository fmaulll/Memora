import SwiftUI

struct AITestView: View {

    @State private var isLoading = false
    @State private var result: DeckPlanResponse?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {

            Button {
                generateTestPlan()
            } label: {
                Text(isLoading ? "Generating..." : "Generate AI Test")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.purple, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(isLoading)

            if let result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        Text(result.title)
                            .font(.title.bold())

                        Text(result.subject)
                            .foregroundStyle(.secondary)

                        Text(result.educationLevel)
                            .foregroundStyle(.secondary)

                        ForEach(result.chapters) { chapter in
                            HStack {
                                Text(chapter.title)

                                Spacer()

                                Text("\(chapter.cardCount)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("AI Test")
    }

    private func generateTestPlan() {
        isLoading = true
        errorMessage = nil
        result = nil

        Task {
            do {
                // Step 1: Generate the learning plan
                let plan = try await AIService.shared.generatePlan(
                    topic: "Python programming from scratch",
                    educationLevel: "University",
                    studyGoal: "Learn Python fundamentals",
                    cardCount: 20
                )

                print("========== AI PLAN ==========")
                print("TITLE:", plan.title)
                print("SUBJECT:", plan.subject)

                for chapter in plan.chapters {
                    print(
                        "\(chapter.title): \(chapter.cardCount) cards"
                    )
                }

                // Step 2: Generate the actual flashcards
                let deck = try await AIService.shared.generateDeck(
                    from: plan
                )

                print("========== AI DECK ==========")
                print("TITLE:", deck.title)
                print("SUBJECT:", deck.subject)

                for chapter in deck.chapters {
                    print("")
                    print("CHAPTER:", chapter.title)
                    print("CARDS:", chapter.cards.count)

                    for card in chapter.cards {
                        print("Q:", card.front)
                        print("A:", card.back)
                    }
                }

                await MainActor.run {
                    result = plan
                    isLoading = false
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }

                print("❌ AI TEST ERROR:", error)
            }
        }
    }
}