import SwiftData

enum MemoraSchema {
    // Keep the existing unversioned store and entity names. S2 only adds optional
    // deck properties and an independent entity for inferred lightweight migration.
    static var current: Schema {
        Schema([
            Item.self,
            StudyDeck.self,
            StudyFlashcardCard.self,
            LocalUserProfile.self,
            PendingStudyProgress.self
        ])
    }
}
