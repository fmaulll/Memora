import Foundation

// MARK: - Exam Type

enum ExamType: String, Codable, CaseIterable, Identifiable {
    case firstHalf = "first_half"
    case secondHalf = "second_half"
    case final = "final"

    var id: String { rawValue }
}

// MARK: - Exam Status

enum ExamStatus: String, Codable {
    case locked
    case unlocked
    case completed
}

// MARK: - Exam Progression

struct ExamProgressionResponse: Decodable {
    let deckID: UUID
    let exams: [ExamStatusResponse]

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id"
        case exams
    }
}

struct ExamStatusResponse: Decodable, Identifiable {
    let examID: UUID
    let examType: ExamType
    let status: ExamStatus
    let passed: Bool
    let bestScore: Int?
    let attemptCount: Int
    let completedAt: Date?

    var id: UUID { examID }

    enum CodingKeys: String, CodingKey {
        case examID = "exam_id"
        case examType = "exam_type"
        case status
        case passed
        case bestScore = "best_score"
        case attemptCount = "attempt_count"
        case completedAt = "completed_at"
    }
}

// MARK: - Exam Questions

struct ExamQuestionResponse: Decodable, Identifiable {
    let id: UUID
    let position: Int
    let questionType: String
    let question: String
    let options: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case questionType = "question_type"
        case question
        case options
    }
}

struct ExamQuestionsResponse: Decodable {
    let examID: UUID
    let examType: ExamType
    let questionCount: Int
    let questions: [ExamQuestionResponse]

    enum CodingKeys: String, CodingKey {
        case examID = "exam_id"
        case examType = "exam_type"
        case questionCount = "question_count"
        case questions
    }
}

// MARK: - Exam Submission

struct ExamAnswer: Encodable {
    let questionID: UUID
    let answer: String

    enum CodingKeys: String, CodingKey {
        case questionID = "question_id"
        case answer
    }
}

struct ExamSubmissionRequest: Encodable {
    let answers: [ExamAnswer]
}

struct ExamSubmissionResponse: Decodable {
    let examID: UUID
    let examType: ExamType
    let totalQuestions: Int
    let correctAnswers: Int
    let incorrectAnswers: Int
    let score: Double
    let passingScore: Double
    let passed: Bool
    let attemptNumber: Int
    let nextExamType: ExamType?
    let nextExamUnlocked: Bool
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case examID = "exam_id"
        case examType = "exam_type"
        case totalQuestions = "total_questions"
        case correctAnswers = "correct_answers"
        case incorrectAnswers = "incorrect_answers"
        case score
        case passingScore = "passing_score"
        case passed
        case attemptNumber = "attempt_number"
        case nextExamType = "next_exam_type"
        case nextExamUnlocked = "next_exam_unlocked"
        case completed
    }
}
