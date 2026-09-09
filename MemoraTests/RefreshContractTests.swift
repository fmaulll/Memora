import Foundation
import Testing
@testable import Memora

@MainActor
struct RefreshContractTests {
    @Test func serverFailurePreservesTokensThenRetryDecodesMigratedUser() async throws {
        let keychain = KeychainService(service: "refresh-contract-tests.\(UUID())")
        defer { keychain.deleteAccessToken(); keychain.deleteRefreshToken() }
        try keychain.saveAccessToken("existing-access")
        try keychain.saveRefreshToken("existing-refresh")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshStubProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = AuthAPI(client: APIClient(baseURL: URL(string: "https://refresh-test.invalid")!, session: session), keychain: keychain)

        do {
            _ = try await api.refreshAccessToken()
            Issue.record("Expected the first refresh to report HTTP 500")
        } catch APIError.httpError(let status, _) {
            #expect(status == 500)
        }
        #expect(try keychain.getAccessToken() == "existing-access")
        #expect(try keychain.getRefreshToken() == "existing-refresh")

        do {
            _ = try await api.createAnonymousUser(name: "Do not replace")
            Issue.record("Saved credentials must block anonymous account creation")
        } catch APIError.existingSession { }
        #expect(try keychain.getRefreshToken() == "existing-refresh")

        let refreshed = try await api.refreshAccessToken()
        #expect(refreshed.user.appAccountToken.uuidString.lowercased() == "5c54af77-c212-4e1e-90e5-295e62478211")
        #expect(refreshed.user.freeAIDeckAvailable)
        #expect(refreshed.user.entitlement.isSubscribed)
        #expect(refreshed.user.entitlement.status == "active")
        #expect(!refreshed.user.entitlement.autoRenew)
        #expect(try keychain.getAccessToken() == "new-access")
        #expect(try keychain.getRefreshToken() == "new-refresh")
    }
}

private final class RefreshStubProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var callsByHost: [String: Int] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // URLSession may deliver the JSON body as a stream to URLProtocol.
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: String]
        guard request.url?.path == "/auth/refresh", request.httpMethod == "POST",
              object == ["refresh_token": "existing-refresh"], request.value(forHTTPHeaderField: "Authorization") == nil else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        Self.lock.lock()
        let host = request.url!.host!
        let count = Self.callsByHost[host, default: 0]
        Self.callsByHost[host] = count + 1
        Self.lock.unlock()
        let data: Data
        let status: Int
        if count == 0 {
            status = 500
            data = Data(#"{"detail":"Database migration required"}"#.utf8)
        } else {
            status = 200
            data = Data(#"{"user":{"id":"68723efa-e2e6-412f-ad9e-18d17b6c19af","name":"Alex","email":"alex@example.com","created_at":"2026-09-10T00:00:00Z","is_anonymous":false,"app_account_token":"5c54af77-c212-4e1e-90e5-295e62478211","free_ai_deck_available":true,"entitlement":{"is_subscribed":true,"status":"active","product_id":"test.monthly","expires_at":"2099-10-10T00:00:00Z","auto_renew":false,"grace_period_expires_at":null,"revoked_at":null,"last_verified_at":"2026-09-10T00:00:00.123Z"}},"access_token":"new-access","refresh_token":"new-refresh","token_type":"bearer"}"#.utf8)
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                                           headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
