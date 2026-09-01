import Foundation
import SwiftData

@Model
final class LocalUserProfile {

    @Attribute(.unique)
    var id: UUID

    // Backend user ID.
    // nil means this is still a guest.
    var userId: UUID?

    var name: String

    var email: String?

    var educationLevel: String?

    var studyReason: String?

    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
        name: String,
        email: String? = nil,
        educationLevel: String? = nil,
        studyReason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.email = email
        self.educationLevel = educationLevel
        self.studyReason = studyReason
        self.createdAt = createdAt
    }
}