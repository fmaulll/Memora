import Foundation

final class AIService {

    static let shared = AIService()

    private init() {}

    // MARK: - Generate Plan

    func generatePlan(
        topic: String,
        educationLevel: String,
        studyGoal: String,
        learningDepth: String
    ) async throws -> DeckPlanResponse {

        let request = DeckPlanRequest(
            topic: topic,
            educationLevel: educationLevel,
            studyGoal: studyGoal,
            learningDepth: learningDepth
        )

        return try await APIClient.shared.request(
            endpoint: "/ai/decks/plan",
            method: .post,
            body: request,
            timeout: 300
        )
    }

    // MARK: - Generate Cards

    func generateDeck(
        from plan: DeckPlanResponse
    ) async throws -> GeneratedDeckResponse {

        return try await APIClient.shared.request(
            endpoint: "/ai/decks/generate",
            method: .post,
            body: plan,
            timeout: 300
        )
    }
}