import Foundation

final class AIService {

    static let shared = AIService()

    private init() {}

    // MARK: - Generate Plan

    func generatePlan(
        topic: String,
        educationLevel: String,
        studyPurpose: String,
        studyGoal: String,
        learningDepth: String,
        targetDate: Date?
    ) async throws -> DeckPlanResponse {

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let formattedTargetDate = targetDate.map {
            dateFormatter.string(from: $0)
        }

        let request = DeckPlanRequest(
            topic: topic,
            educationLevel: educationLevel,
            studyPurpose: studyPurpose,
            studyGoal: studyGoal,
            learningDepth: learningDepth,
            targetDate: formattedTargetDate
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
        plan: DeckPlanResponse,
        studyPurpose: String,
        targetDate: Date?
    ) async throws -> GeneratedDeckWithTimelineResponse {

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let formattedTargetDate = targetDate.map {
            dateFormatter.string(from: $0)
        }

        let request = GenerateDeckRequest(
            plan: plan,
            studyPurpose: studyPurpose,
            targetDate: formattedTargetDate
        )

        let response: GeneratedDeckWithTimelineResponse =
            try await APIClient.shared.request(
                endpoint: "/ai/decks/generate",
                method: .post,
                body: request,
                timeout: 30
            )

        return response
    }

    // MARK: - Generation Status

    func fetchGenerationStatus(
        deckID: UUID
    ) async throws -> DeckGenerationStatusResponse {

        return try await APIClient.shared.request(
            endpoint: "/decks/\(deckID.uuidString)/generation-status",
            method: .get,
            timeout: 30
        )
    }
}