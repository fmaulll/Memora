import Foundation
import SwiftData

@Model
final class LocalUserProfile {

    @Attribute(.unique)
    var id: UUID

    var name: String
    var email: String
    var createdAt: Date

    init(
        id: UUID,
        name: String,
        email: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}