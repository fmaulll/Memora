import Foundation
import CryptoKit

/// One pending intent per exact account/body. Kept across launches until local
/// deck creation succeeds; editing the plan creates a different intent.
@MainActor
final class GenerationRequestStore {
    static let shared = GenerationRequestStore()
    struct Intent: Codable {
        let key: UUID
        let request: GenerateDeckRequest
        var deckID: UUID?
        var requiresSubscription: Bool? = nil
    }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func storageKey(account: UUID, request: GenerateDeckRequest) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let hash = SHA256.hash(data: try encoder.encode(request)).map { String(format: "%02x", $0) }.joined()
        return "generationIntent.\(account.uuidString).\(hash)"
    }
    func intent(account: UUID, request: GenerateDeckRequest, requiresSubscription: Bool = false) throws -> Intent {
        let storage = try storageKey(account: account, request: request)
        if let data = defaults.data(forKey: storage) { return try JSONDecoder().decode(Intent.self, from: data) }
        let intent = Intent(key: UUID(), request: request, deckID: nil, requiresSubscription: requiresSubscription)
        defaults.set(try JSONEncoder().encode(intent), forKey: storage)
        return intent
    }
    func record(account: UUID, intent: Intent, deckID: UUID) throws {
        var saved = intent; saved.deckID = deckID
        defaults.set(try JSONEncoder().encode(saved), forKey: try storageKey(account: account, request: intent.request))
    }
    func pending(account: UUID) -> [Intent] {
        defaults.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix("generationIntent.\(account.uuidString)."), let data = value as? Data else { return nil }
            return try? JSONDecoder().decode(Intent.self, from: data)
        }.sorted { $0.key.uuidString < $1.key.uuidString }
    }

    func move(from source: UUID, to destination: UUID) throws {
        for intent in pending(account: source) {
            let destinationKey = try storageKey(account: destination, request: intent.request)
            let data = try JSONEncoder().encode(intent)
            if let existing = defaults.data(forKey: destinationKey), existing != data {
                defaults.set(data, forKey: destinationKey + "." + intent.key.uuidString)
            } else {
                defaults.set(data, forKey: destinationKey)
            }
        }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("generationIntent.\(source.uuidString).") {
            defaults.removeObject(forKey: key)
        }
    }

    func complete(account: UUID, deckID: UUID) {
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix("generationIntent.\(account.uuidString).") {
            guard let data = value as? Data,
                  let intent = try? JSONDecoder().decode(Intent.self, from: data), intent.deckID == deckID else { continue }
            defaults.removeObject(forKey: key)
        }
    }
}
