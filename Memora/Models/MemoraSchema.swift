import SwiftData

enum MemoraSchema {
    // Keep the existing store/entity names. Additive optional deck properties
    // and independent operation entities use inferred lightweight migration.
    static var current: Schema {
        Schema([
            Item.self,
            StudyDeck.self,
            StudyFlashcardCard.self,
            LocalUserProfile.self,
            PendingStudyProgress.self,
            PendingStudyReset.self
        ])
    }
}
