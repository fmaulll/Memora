//
//  StudyDeck.swift
//  Memora
//
//  Created by fuckdazeshit on 16/08/26.
//

import Foundation
import SwiftData

@Model
final class StudyDeck {
    var title: String
    var subject: String
    var educationLevel: String
    var createdAt: Date
    var isFavorite: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \StudyFlashcardCard.deck)
    var cards: [StudyFlashcardCard]

    init(
        title: String,
        subject: String,
        educationLevel: String,
        createdAt: Date = .now,
        cards: [StudyFlashcardCard] = []
    ) {
        self.title = title
        self.subject = subject
        self.educationLevel = educationLevel
        self.createdAt = createdAt
        self.cards = cards
    }
}

@Model
final class StudyFlashcardCard {
    var front: String
    var back: String
    var frontImageData: Data?
    var backImageData: Data?
    var deck: StudyDeck?

    init(
        front: String,
        back: String,
        frontImageData: Data? = nil,
        backImageData: Data? = nil
    ) {
        self.front = front
        self.back = back
        self.frontImageData = frontImageData
        self.backImageData = backImageData
    }
}
