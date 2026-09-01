import Foundation
import Observation

@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    var isSubscribed: Bool = false

    private init() {}
}