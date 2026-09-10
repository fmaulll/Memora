import Foundation

/// Keeps the UUID and body stable when the network drops after a local review.
/// The backend returns the original receipt for an identical duplicate event.
@MainActor
final class StudyReviewEventStore {
    static let shared = StudyReviewEventStore()
    private let defaults = UserDefaults.standard

    private func key(_ cardID: UUID) -> String { "pendingStudyReview.\(cardID.uuidString)" }

    func pending(for cardID: UUID) -> StudyReviewRequest? {
        guard let data = defaults.data(forKey: key(cardID)) else { return nil }
        return try? JSONDecoder().decode(StudyReviewRequest.self, from: data)
    }

    func save(_ request: StudyReviewRequest) throws {
        defaults.set(try JSONEncoder().encode(request), forKey: key(request.cardID))
    }

    func clear(cardID: UUID) { defaults.removeObject(forKey: key(cardID)) }
}
