import Foundation

final class APIClient {

    static let shared = APIClient()

    private let accounts: LocalAccountStore?
    private let accessToken: () throws -> String?

    init(baseURL: URL = URL(string: "http://192.168.1.13:8000")!,
         session: URLSession? = nil, accounts: LocalAccountStore? = nil,
         accessToken: @escaping () throws -> String? = { try KeychainService.shared.getAccessToken() }) {
        self.baseURL = baseURL
        self.accounts = accounts
        self.accessToken = accessToken
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = session ?? URLSession(configuration: configuration)
    }

    // MARK: - Configuration

    private let baseURL: URL
    private let session: URLSession

    private let decoder = APIJSON.makeDecoder()
    private let encoder = APIJSON.makeEncoder()

    // MARK: - Request

    @MainActor
    func request<Response: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        rawJSONBody: Data? = nil,
        authenticated: Bool = true,
        timeout: TimeInterval? = nil
    ) async throws -> Response {

        // Build authorization on the same actor as account switching, before
        // suspending for the network, so an old sync cannot pick up new tokens.
        let accountStore = accounts ?? .shared
        let revision = accountStore.revision
        let builtRequest = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            authenticated: authenticated
        )

        // A durable operation supplies its already-encoded bytes, never a model
        // to reconstruct. All other transport/auth/error handling stays shared.
        guard body == nil || rawJSONBody == nil else { throw APIError.invalidResponse }
        var request = builtRequest
        if let rawJSONBody {
            request.httpBody = rawJSONBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let timeout {
            request.timeoutInterval = timeout
        }

        let data: Data

        do {
            let (responseData, response) = try await session.data(
                for: request
            )

            try accountStore.validateRevision(revision)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try validateResponse(
                httpResponse,
                data: responseData
            )

            data = responseData

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

    func upload<Response: Decodable>(
        endpoint: String,
        files: [URL],
        fieldName: String,
        authenticated: Bool = true,
        timeout: TimeInterval? = nil
    ) async throws -> Response {
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
           let token = try accessToken() {
            request.setValue(
                "Bearer \(token)",
                forHTTPHeaderField: "Authorization"
            )
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try validateResponse(httpResponse, data: data)

            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }

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
        authenticated: Bool = true
    ) async throws {

        let accountStore = accounts ?? .shared
        let revision = accountStore.revision
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

            try accountStore.validateRevision(revision)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try validateResponse(
                httpResponse,
                data: responseData
            )

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
            if let token = try accessToken() {
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

        guard (200...299).contains(response.statusCode) else {
            throw APIError.responseError(statusCode: response.statusCode, data: data)
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