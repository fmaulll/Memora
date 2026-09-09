import Foundation

/// A card leaves the session only after two consecutive successful recalls.
struct StudySessionQueue {
    private(set) var cardIDs: [UUID]
    private(set) var confirmationIDs: Set<UUID>

    init(cardIDs: [UUID], confirmationIDs: Set<UUID> = []) {
        var seen = Set<UUID>()
        self.cardIDs = cardIDs.filter { seen.insert($0).inserted }
        self.confirmationIDs = confirmationIDs.intersection(seen)
    }

    /// Returns true only when this rating completes the current card.
    @discardableResult
    mutating func rate(_ rating: CardRating) -> Bool {
        guard !cardIDs.isEmpty else { return false }
        let cardID = cardIDs.removeFirst()
        switch rating {
        case .again:
            confirmationIDs.remove(cardID)
            cardIDs.insert(cardID, at: min(1, cardIDs.count))
            return false
        case .good:
            if confirmationIDs.remove(cardID) != nil {
                return true
            }
            confirmationIDs.insert(cardID)
            // Put a few other cards between successful recall and confirmation.
            cardIDs.insert(cardID, at: min(3, cardIDs.count))
            return false
        }
    }
}
