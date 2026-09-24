import Foundation

@MainActor
final class StudyProgressAPI {
    static let shared = StudyProgressAPI()
    private init() {}

    func get(deckID: UUID) async throws -> StudyProgressResponse {
        try await APIClient.shared.request(endpoint: "/decks/\(deckID)/study-progress")
    }

    func submit(_ submission: StudyProgressSubmission) async throws -> StudyProgressSubmissionResponse {
        try await APIClient.shared.request(
            endpoint: "/study/progress/submissions", method: .post, body: submission
        )
    }

    func reset(deckID: UUID, request: StudyProgressResetRequest) async throws -> StudyProgressResetResponse {
        try await APIClient.shared.request(
            endpoint: "/decks/\(deckID)/study-progress/reset", method: .post, body: request
        )
    }
}
