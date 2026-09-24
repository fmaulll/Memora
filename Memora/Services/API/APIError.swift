import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case businessError(statusCode: Int, code: String, message: String)
    case validationError(statusCode: Int, issues: [APIValidationIssue])
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case noRefreshToken
    case unauthorized

    var statusCode: Int? {
        switch self {
        case .httpError(let status, _), .businessError(let status, _, _), .validationError(let status, _):
            return status
        case .unauthorized: return 401
        default: return nil
        }
    }

    var businessCode: String? {
        if case .businessError(_, let code, _) = self { return code }
        return nil
    }

    static func responseError(statusCode: Int, data: Data?) -> APIError {
        // Preserve the app's existing authentication handling.
        if statusCode == 401 { return .unauthorized }
        if let data, let response = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            switch response.detail {
            case .message(let message): return .httpError(statusCode: statusCode, message: message)
            case .business(let detail):
                return .businessError(statusCode: statusCode, code: detail.code, message: detail.message)
            case .validation(let issues): return .validationError(statusCode: statusCode, issues: issues)
            }
        }
        let message = data.flatMap { String(data: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .httpError(statusCode: statusCode, message: message?.isEmpty == false ? message : nil)
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."

        case .invalidResponse:
            return "The server returned an invalid response."

        case .httpError(let statusCode, let message):
            if let message {
                return "Server error \(statusCode): \(message)"
            }

            return "Server error \(statusCode)."

        case .decodingError(let error):
            return "Failed to decode server response: \(error.localizedDescription)"

        case .businessError(let statusCode, _, let message):
            return "Server error \(statusCode): \(message)"

        case .validationError(_, let issues):
            return issues.map(\.message).joined(separator: "\n")

        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .unauthorized:
            return "Unauthorized access. Please log in again."

        case .noRefreshToken:
            return "No refresh token available. Please log in again."

        }
    }
}

struct APIValidationIssue: Decodable {
    enum Location: Decodable, Equatable {
        case field(String)
        case index(Int)

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let index = try? value.decode(Int.self) { self = .index(index) }
            else { self = .field(try value.decode(String.self)) }
        }
    }

    let type: String
    let location: [Location]
    let message: String

    enum CodingKeys: String, CodingKey {
        case type, location = "loc", message = "msg"
    }
}

private struct APIErrorResponse: Decodable {
    struct Business: Decodable {
        let code: String
        let message: String
    }

    enum Detail: Decodable {
        case message(String)
        case business(Business)
        case validation([APIValidationIssue])

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let message = try? value.decode(String.self) { self = .message(message) }
            else if let business = try? value.decode(Business.self) { self = .business(business) }
            else { self = .validation(try value.decode([APIValidationIssue].self)) }
        }
    }

    let detail: Detail
}
