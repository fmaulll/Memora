import Foundation

struct SubscriptionEntitlement: Codable, Equatable {
    let isSubscribed: Bool
    let status: String
    let productID: String?
    let expiresAt: Date?
    let autoRenew: Bool
    let gracePeriodExpiresAt: Date?
    let revokedAt: Date?
    let lastVerifiedAt: Date?

    enum CodingKeys: String, CodingKey {
        case isSubscribed = "is_subscribed", status, productID = "product_id"
        case expiresAt = "expires_at", autoRenew = "auto_renew"
        case gracePeriodExpiresAt = "grace_period_expires_at"
        case revokedAt = "revoked_at", lastVerifiedAt = "last_verified_at"
    }

    // Never extend the server's access decision past Apple's supplied deadline.
    func allowsAccess(at now: Date) -> Bool {
        guard isSubscribed, revokedAt == nil else { return false }
        let deadline = status == "grace_period" ? gracePeriodExpiresAt : expiresAt
        guard status == "active" || status == "grace_period", let deadline else { return false }
        return now < deadline
    }
}

struct SubscriptionResponse: Decodable {
    let appAccountToken: UUID
    let entitlement: SubscriptionEntitlement
    let freeAIDeckAvailable: Bool
    enum CodingKeys: String, CodingKey {
        case appAccountToken = "app_account_token", entitlement
        case freeAIDeckAvailable = "free_ai_deck_available"
    }
}

struct VerifyApplePurchaseRequest: Encodable {
    let signedTransaction: String
    enum CodingKeys: String, CodingKey { case signedTransaction = "signed_transaction" }
}

@MainActor
final class SubscriptionAPI {
    static let shared = SubscriptionAPI()
    func status(reconcile: Bool = false) async throws -> SubscriptionResponse {
        try await APIClient.shared.request(endpoint: reconcile ? "/subscriptions/reconcile" : "/subscriptions/me",
                                           method: reconcile ? .post : .get)
    }
    func verify(_ signedTransaction: String) async throws -> SubscriptionResponse {
        try await APIClient.shared.request(endpoint: "/subscriptions/apple/verify", method: .post,
                                           body: VerifyApplePurchaseRequest(signedTransaction: signedTransaction))
    }
}
