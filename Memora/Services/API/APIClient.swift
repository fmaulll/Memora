import Foundation

final class APIClient {

    static let shared = APIClient()

    init(baseURL: URL? = nil, session: URLSession? = nil) {
        self.baseURL = baseURL ?? URL(string: Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
                                     ?? "http://192.168.1.3:8000")!
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: configuration)
        }
    }

    private let baseURL: URL
    private let session: URLSession

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = formatter.date(from: string) {
                return date
            }

            formatter.formatOptions = [
                .withInternetDateTime
            ]

            if let date = formatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ISO8601 date: \(string)"
                )
            )
        }

        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()

        encoder.dateEncodingStrategy = .iso8601

        return encoder
    }()

    // MARK: - Request

    @MainActor
    func request<Response: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        authenticated: Bool = true,
        timeout: TimeInterval? = nil,
        headers: [String: String] = [:],
        retryAfterRefresh: Bool = true
    ) async throws -> Response {

        // Build authorization on the same actor as account switching, before
        // suspending for the network, so an old sync cannot pick up new tokens.
        let revision = LocalAccountStore.shared.revision
        let builtRequest = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            authenticated: authenticated
        )

        var request = builtRequest
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        if let timeout {
            request.timeoutInterval = timeout
        }

        let data: Data

        do {
            let (responseData, response) = try await session.data(
                for: request
            )

            try LocalAccountStore.shared.validateRevision(revision)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if httpResponse.statusCode == 401, endpoint == "/auth/merge" {
                let detail = try? decoder.decode(BackendErrorDetail.self, from: responseData)
                throw APIError.backend(statusCode: 401, code: detail?.code ?? "invalid_credentials",
                                       message: detail?.message ?? "The existing account’s email or password was not accepted.")
            }
            try validateResponse(
                httpResponse,
                data: responseData
            )

            data = responseData

        } catch APIError.unauthorized where authenticated && retryAfterRefresh && endpoint != "/auth/merge" {
            try LocalAccountStore.shared.validateRevision(revision)
            _ = try await AuthAPI.shared.refreshAccessToken()
            try LocalAccountStore.shared.validateRevision(revision)
            return try await self.request(endpoint: endpoint, method: method, body: body,
                                          authenticated: authenticated, timeout: timeout, headers: headers,
                                          retryAfterRefresh: false)
        } catch let error as APIError {
            throw error

        } catch {
            throw APIError.networkError(error)
        }

        do {
            return try decoder.decode(
                Response.self,
                from: data
            )
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Multipart Upload

    @MainActor
    func upload<Response: Decodable>(
        endpoint: String,
        files: [URL],
        fieldName: String,
        authenticated: Bool = true,
        timeout: TimeInterval? = nil,
        retryAfterRefresh: Bool = true
    ) async throws -> Response {
        let revision = LocalAccountStore.shared.revision
        let cleanEndpoint = endpoint.hasPrefix("/")
            ? String(endpoint.dropFirst())
            : endpoint
        let url = baseURL.appendingPathComponent(cleanEndpoint)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for fileURL in files {
            let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            let fileData: Data

            do {
                fileData = try Data(contentsOf: fileURL)
            } catch {
                throw APIError.encodingError(error)
            }

            let filename = fileURL.lastPathComponent.replacingOccurrences(
                of: "\"",
                with: ""
            )
            let header = "--\(boundary)\r\n"
                + "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n"
                + "Content-Type: application/octet-stream\r\n\r\n"

            body.append(Data(header.utf8))
            body.append(fileData)
            body.append(Data("\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        if let timeout {
            request.timeoutInterval = timeout
        }

        if authenticated,
           let token = try KeychainService.shared.getAccessToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        do {
            let (data, response) = try await session.data(for: request)

            try LocalAccountStore.shared.validateRevision(revision)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try validateResponse(httpResponse, data: data)

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

        } catch APIError.unauthorized where authenticated && retryAfterRefresh {
            try LocalAccountStore.shared.validateRevision(revision)
            _ = try await AuthAPI.shared.refreshAccessToken()
            try LocalAccountStore.shared.validateRevision(revision)
            return try await upload(endpoint: endpoint, files: files, fieldName: fieldName,
                                    authenticated: authenticated, timeout: timeout, retryAfterRefresh: false)
        } catch let error as APIError {
            throw error

        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Request Without Response Body

    @MainActor
    func requestWithoutResponse(
        endpoint: String,
        method: HTTPMethod = .delete,
        body: (any Encodable)? = nil,
        authenticated: Bool = true,
        retryAfterRefresh: Bool = true
    ) async throws {

        let revision = LocalAccountStore.shared.revision
        let request = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            authenticated: authenticated
        )

        do {
            let (responseData, response) = try await session.data(
                for: request
            )

            try LocalAccountStore.shared.validateRevision(revision)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try validateResponse(
                httpResponse,
                data: responseData
            )

        } catch APIError.unauthorized where authenticated && retryAfterRefresh {
            try LocalAccountStore.shared.validateRevision(revision)
            _ = try await AuthAPI.shared.refreshAccessToken()
            try LocalAccountStore.shared.validateRevision(revision)
            try await requestWithoutResponse(endpoint: endpoint, method: method, body: body,
                                             authenticated: authenticated, retryAfterRefresh: false)
        } catch let error as APIError {
            throw error

        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Build Request

    private func buildRequest(
        endpoint: String,
        method: HTTPMethod,
        body: (any Encodable)?,
        authenticated: Bool
    ) throws -> URLRequest {

        let cleanEndpoint = endpoint.hasPrefix("/")
            ? String(endpoint.dropFirst())
            : endpoint

        let url = baseURL.appendingPathComponent(
            cleanEndpoint
        )

        var request = URLRequest(url: url)

        request.httpMethod = method.rawValue

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        if body != nil {
            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )
        }

        if authenticated {
            if let token = try KeychainService.shared.getAccessToken() {
                request.setValue(
                    "Bearer \(token)",
                    forHTTPHeaderField: "Authorization"
                )
            }
        }

        if let body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encodingError(error)
            }
        }

        return request
    }

    // MARK: - Response Validation

    private func validateResponse(
        _ response: HTTPURLResponse,
        data: Data?
    ) throws {

        switch response.statusCode {

        case 200...299:
            return

        case 401:
            throw APIError.unauthorized

        default:

            let detail = data.flatMap { try? decoder.decode(BackendErrorDetail.self, from: $0) }
            if let code = detail?.code {
                throw APIError.backend(statusCode: response.statusCode, code: code, message: detail!.message)
            }
            throw APIError.httpError(statusCode: response.statusCode, message: detail?.message)
        }
    }
}


// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}