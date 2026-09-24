import Foundation

@MainActor
final class StudyPlanAPI {
    static let shared = StudyPlanAPI()
    private init() {}

    func get(deckID: UUID) async throws -> StudyPlanResponse {
        try await APIClient.shared.request(endpoint: "/decks/\(deckID)/study-plan")
    }

    func create(deckID: UUID, request: StudyPlanCreateRequest) async throws -> StudyPlanResponse {
        try await APIClient.shared.request(
            endpoint: "/decks/\(deckID)/study-plan", method: .post, body: request
        )
    }

    func recalculate(deckID: UUID) async throws -> StudyPlanResponse {
        try await APIClient.shared.request(
            endpoint: "/decks/\(deckID)/study-plan/recalculate", method: .post
        )
    }
}
