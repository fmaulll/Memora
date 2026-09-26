import Foundation

@MainActor
final class StudyProgressAPI {
    static let shared = StudyProgressAPI()
    private let client: APIClient
    init(client: APIClient = .shared) { self.client = client }

    func submit(payload: Data) async throws -> StudyProgressSubmissionResponse {
        try await client.request(endpoint: "/study/progress/submissions", method: .post, rawJSONBody: payload)
    }

    func get(deckID: UUID, timeout: TimeInterval? = nil) async throws -> StudyProgressResponse {
        try await client.request(endpoint: "/decks/\(deckID)/study-progress", timeout: timeout)
    }

    func submit(_ submission: StudyProgressSubmission) async throws -> StudyProgressSubmissionResponse {
        try await client.request(
            endpoint: "/study/progress/submissions", method: .post, body: submission
        )
    }

    func reset(deckID: UUID, payload: Data) async throws -> StudyProgressResetResponse {
        try await client.request(endpoint: "/decks/\(deckID)/study-progress/reset", method: .post, rawJSONBody: payload)
    }

    func reset(deckID: UUID, request: StudyProgressResetRequest) async throws -> StudyProgressResetResponse {
        try await client.request(
            endpoint: "/decks/\(deckID)/study-progress/reset", method: .post, body: request
        )
    }
}
