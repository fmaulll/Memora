import Foundation
import SwiftData

enum StudyResetState: String {
    case pending, confirmed, rejectedNeedsReconciliation, rejected, blocked, completed

    var fencesStudy: Bool {
        self == .pending || self == .confirmed || self == .rejectedNeedsReconciliation || self == .blocked
    }
}

enum StudyResetError: LocalizedError {
    case pending, sessionInvalidated, scopeChanged, blocked(String), unavailable

    var errorDescription: String? {
        switch self {
        case .pending: return "A reset is awaiting completion for this deck. Connect to the server and retry Reset Progress before studying."
        case .sessionInvalidated: return "This study session was reset. Close it and start a new session."
        case .scopeChanged: return "Progress or chapters changed on the server. Local progress was kept. Close this message and confirm Reset Progress again if you still want to reset."
        case .blocked(let code): return "Reset could not be verified (\(code)). Your local progress was kept. This operation needs investigation before another reset."
        case .unavailable: return "Reset could not finish. Connect to the server and try again. Any saved reset request will be retried safely."
        }
    }

    var canRetry: Bool {
        switch self { case .scopeChanged, .blocked, .sessionInvalidated: return false; default: return true }
    }
}

/// Independent of the content cache. Logout must not delete an uncertain reset.
@Model
final class PendingStudyReset {
    private(set) var id: UUID
    private(set) var accountID: UUID
    private(set) var scopeID: UUID
    private(set) var createdAt: Date
    private(set) var payloadData: Data
    private(set) var stateRawValue: String
    private(set) var receiptData: Data?
    private(set) var failureCode: String?

    init(accountID: UUID, scopeID: UUID, expected: [DeckProgressEpoch]) throws {
        let id = UUID()
        self.id = id
        self.accountID = accountID
        self.scopeID = scopeID
        createdAt = Date()
        payloadData = try APIJSON.makeEncoder().encode(StudyProgressResetRequest(resetID: id, expectedDecks: expected))
        stateRawValue = StudyResetState.pending.rawValue
    }

    func request() throws -> StudyProgressResetRequest {
        try APIJSON.makeDecoder().decode(StudyProgressResetRequest.self, from: payloadData)
    }

    func transition(_ state: StudyResetState, code: String? = nil, receipt: StudyProgressResetResponse? = nil) throws {
        if let receipt { receiptData = try APIJSON.makeEncoder().encode(receipt) }
        stateRawValue = state.rawValue
        failureCode = code
    }
}
