import Foundation

final class ExamAPI {

    static let shared = ExamAPI()

    private init() {
    }

    // MARK: - Exam Status

    func getExams(
        parentDeckID: UUID
    ) async throws -> ExamProgressionResponse {
        try await APIClient.shared.request(
            endpoint: "/decks/\(parentDeckID.uuidString)/exams",
            method: .get
        )
    }

    // MARK: - Generate Exam

    func generateExam(
        parentDeckID: UUID,
        examType: ExamType
    ) async throws -> ExamQuestionsResponse {
        try await APIClient.shared.request(
            endpoint: "/decks/\(parentDeckID.uuidString)/exams/\(examType.rawValue)/generate",
            method: .post,
            timeout: 300
        )
    }

    // MARK: - Get Exam Questions

    func getExam(
        examID: UUID
    ) async throws -> ExamQuestionsResponse {
        try await APIClient.shared.request(
            endpoint: "/exams/\(examID.uuidString)",
            method: .get
        )
    }

    // MARK: - Submit Exam

    func submitExam(
        examID: UUID,
        answers: [ExamAnswer]
    ) async throws -> ExamSubmissionResponse {
        let request = ExamSubmissionRequest(answers: answers)

        return try await APIClient.shared.request(
            endpoint: "/exams/\(examID.uuidString)/submit",
            method: .post,
            body: request
        )
    }
}
