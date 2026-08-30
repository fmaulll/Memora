import Foundation

final class APIClient {

    static let shared = APIClient()

    private init() {}

    // MARK: - Configuration

    private let baseURL = URL(
        // string: "http://127.0.0.1:8000"

        string: "http://192.168.1.8:8000"
    )!

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300

        return URLSession(configuration: configuration)
    }()

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

    func request<Response: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        authenticated: Bool = true,
        timeout: TimeInterval? = nil
    ) async throws -> Response {

        let builtRequest = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            authenticated: authenticated
        )

        var request = builtRequest

        if let timeout {
            request.timeoutInterval = timeout
        }

        let data: Data

        do {
            let (responseData, response) = try await session.data(
                for: request
            )

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

    // MARK: - Request Without Response Body

    func requestWithoutResponse(
        endpoint: String,
        method: HTTPMethod = .delete,
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws {

        let request = try buildRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            authenticated: authenticated
        )

        do {
            let (_, response) = try await session.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            try validateResponse(
                httpResponse,
                data: nil
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

            var message: String?

            if let data,
               !data.isEmpty {

                struct ErrorResponse: Decodable {
                    let detail: String?
                }

                if let errorResponse = try? decoder.decode(
                    ErrorResponse.self,
                    from: data
                ) {
                    message = errorResponse.detail
                }
            }

            throw APIError.httpError(
                statusCode: response.statusCode,
                message: message
            )
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