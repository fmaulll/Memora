import Foundation
import Observation
import StoreKit

/// Apple transactions are only finished after the backend accepts them.
/// StoreKit's persistent unfinished sequence is the retry queue across launches.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private(set) var entitlement: SubscriptionEntitlement?
    private(set) var appAccountToken: UUID?
    private(set) var freeAIDeckAvailable = false
    private(set) var products: [Product] = []
    private(set) var isBusy = false
    private(set) var isLoadingProducts = false
    var message: String?
    private var userID: UUID?
    private var clock = Date()
    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var processing = Set<UInt64>()

    var isSubscribed: Bool { entitlement?.allowsAccess(at: clock) == true }
    static var productIDs: [String] {
        (Bundle.main.object(forInfoDictionaryKey: "SubscriptionProductIDs") as? [String] ?? [])
            .filter { !$0.isEmpty && !$0.contains("example") }
    }
    static var privacyURL: URL? { configuredURL("PrivacyPolicyURL") }
    static var termsURL: URL? { configuredURL("TermsOfUseURL") }
    private static func configuredURL(_ key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    var purchasesConfigured: Bool {
        !Self.productIDs.isEmpty && Self.privacyURL != nil && Self.termsURL != nil
    }

    private init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.receive(result)
            }
        }
    }

    func apply(user: UserResponse) {
        if userID != user.id { reset() }
        userID = user.id
        appAccountToken = user.appAccountToken
        entitlement = user.entitlement
        freeAIDeckAvailable = user.freeAIDeckAvailable
        clock = .now
        scheduleExpiry()
    }

    private func apply(_ response: SubscriptionResponse) {
        appAccountToken = response.appAccountToken
        entitlement = response.entitlement
        freeAIDeckAvailable = response.freeAIDeckAvailable
        clock = .now
        scheduleExpiry()
    }

    func reset() {
        retryTask?.cancel(); retryTask = nil
        expiryTask?.cancel(); expiryTask = nil
        userID = nil; appAccountToken = nil; entitlement = nil
        freeAIDeckAvailable = false; message = nil
        clock = .now
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        let deadline = entitlement?.status == "grace_period"
            ? entitlement?.gracePeriodExpiresAt : entitlement?.expiresAt
        guard let deadline, deadline > .now else { return }
        expiryTask = Task { [weak self] in
            let seconds = max(0, deadline.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            self?.clock = .now
        }
    }

    func refresh(reconcile: Bool = false) async throws {
        guard userID != nil else { throw APIError.unauthorized }
        let revision = LocalAccountStore.shared.revision
        clock = .now
        let response = try await SubscriptionAPI.shared.status(reconcile: reconcile)
        try LocalAccountStore.shared.validateRevision(revision)
        apply(response)
    }

    func resume() async {
        guard userID != nil else { return }
        let revision = LocalAccountStore.shared.revision
        do {
            try await refresh()
            if entitlement?.status == "verification_required" { try await refresh(reconcile: true) }
        } catch {
            guard revision == LocalAccountStore.shared.revision else { return }
            message = error.localizedDescription
        }
        guard revision == LocalAccountStore.shared.revision else { return }
        if await retryUnfinished() { scheduleRetry() }
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        guard purchasesConfigured else {
            message = "Subscriptions aren’t available yet. Please check back later."
            return
        }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: Self.productIDs)
                .filter { $0.type == .autoRenewable }.sorted { $0.price < $1.price }
            message = products.isEmpty ? "No subscription plans are available from the App Store right now." : nil
        } catch { message = error.localizedDescription }
    }

    func purchase(_ product: Product) async {
        guard !isBusy, purchasesConfigured, Self.productIDs.contains(product.id) else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        let revision = LocalAccountStore.shared.revision
        do {
            try await refresh()
            guard let appAccountToken else { throw APIError.unauthorized }
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            try LocalAccountStore.shared.validateRevision(revision)
            switch result {
            case .success(let verification): try await process(verification)
            case .pending: message = "Your purchase is awaiting approval. Access will update after Apple approves it."
            case .userCancelled: break
            @unknown default: message = "The purchase has not completed. Please try again."
            }
        } catch {
            guard revision == LocalAccountStore.shared.revision else { return }
            message = error.localizedDescription
            if (error as? APIError)?.isTransient == true { scheduleRetry() }
        }
    }

    func restore() async {
        guard !isBusy, userID != nil else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        let revision = LocalAccountStore.shared.revision
        do {
            try await AppStore.sync() // Only called by the explicit Restore button.
            try LocalAccountStore.shared.validateRevision(revision)
            var found = false
            var failure: Error?
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.productType == .autoRenewable else { continue }
                found = true
                do { try await process(result) } catch { failure = error }
            }
            try await refresh(reconcile: true)
            if let failure { throw failure }
            message = isSubscribed ? "Your subscription has been restored." : found
                ? "Purchases checked. There is no active subscription for this account."
                : "No current subscription was found for this Apple Account."
        } catch {
            guard revision == LocalAccountStore.shared.revision else { return }
            message = error.localizedDescription
            if (error as? APIError)?.isTransient == true { scheduleRetry() }
        }
    }

    private func process(_ result: VerificationResult<Transaction>) async throws {
        guard let userID else { throw APIError.unauthorized }
        guard case .verified(let transaction) = result else {
            throw APIError.backend(statusCode: 400, code: "unverified_purchase",
                                   message: "Apple could not verify this purchase. No access was granted.")
        }
        guard transaction.productType == .autoRenewable else { return }
        guard processing.insert(transaction.id).inserted else { return }
        defer { processing.remove(transaction.id) }
        let revision = LocalAccountStore.shared.revision
        var pending = try KeychainService.shared.pendingAppleVerifications(userID: userID)
        pending[String(transaction.id)] = result.jwsRepresentation
        try KeychainService.shared.saveAppleVerifications(pending, userID: userID)
        let response: SubscriptionResponse
        do {
            response = try await SubscriptionAPI.shared.verify(result.jwsRepresentation)
        } catch {
            if let apiError = error as? APIError, !apiError.isTransient {
                try? removePending(transactionID: String(transaction.id), userID: userID)
            }
            throw error
        }
        try LocalAccountStore.shared.validateRevision(revision)
        try removePending(transactionID: String(transaction.id), userID: userID)
        apply(response)
        await transaction.finish()
        message = isSubscribed ? "Subscription verified. You’re ready to study." : "Purchase verified. No paid access is currently active."
    }

    private func receive(_ result: VerificationResult<Transaction>) async {
        guard userID != nil else { return } // Unfinished transactions survive sign-out.
        let revision = LocalAccountStore.shared.revision
        do { try await process(result) }
        catch {
            guard revision == LocalAccountStore.shared.revision else { return }
            message = error.localizedDescription
            if (error as? APIError)?.isTransient == true { scheduleRetry() }
        }
    }

    private func removePending(transactionID: String, userID: UUID) throws {
        var pending = try KeychainService.shared.pendingAppleVerifications(userID: userID)
        pending.removeValue(forKey: transactionID)
        try KeychainService.shared.saveAppleVerifications(pending, userID: userID)
    }

    @discardableResult
    private func retryUnfinished() async -> Bool {
        let revision = LocalAccountStore.shared.revision
        var transientFailure = false
        if let userID {
            do {
                let pending = try KeychainService.shared.pendingAppleVerifications(userID: userID)
                for (id, jws) in pending {
                    guard revision == LocalAccountStore.shared.revision, !Task.isCancelled else { return false }
                    guard let transactionID = UInt64(id), processing.insert(transactionID).inserted else { continue }
                    defer { processing.remove(transactionID) }
                    do {
                        let response = try await SubscriptionAPI.shared.verify(jws)
                        try LocalAccountStore.shared.validateRevision(revision)
                        apply(response)
                        try removePending(transactionID: id, userID: userID)
                    } catch {
                        guard revision == LocalAccountStore.shared.revision else { return false }
                        message = error.localizedDescription
                        if (error as? APIError)?.isTransient == true { transientFailure = true }
                        else { try? removePending(transactionID: id, userID: userID) }
                    }
                }
            } catch { message = error.localizedDescription }
        }
        for await result in Transaction.unfinished {
            guard userID != nil, revision == LocalAccountStore.shared.revision, !Task.isCancelled else { return false }
            do { try await process(result) }
            catch {
                guard revision == LocalAccountStore.shared.revision else { return false }
                message = error.localizedDescription
                transientFailure = transientFailure || (error as? APIError)?.isTransient == true
            }
        }
        return transientFailure
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self] in
            defer { self?.retryTask = nil }
            for delay in [2, 4, 8, 16, 32, 60] {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, self.userID != nil else { return }
                if !(await self.retryUnfinished()) { return }
            }
        }
    }
}
