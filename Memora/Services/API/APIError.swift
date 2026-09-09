import Foundation

enum APIError: LocalizedError {
    case backend(statusCode: Int, code: String, message: String)
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case existingSession
    case noRefreshToken
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .backend(_, _, let message):
            return message
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

        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .unauthorized:
            return "Unauthorized access. Please log in again."

        case .existingSession:
            return "An existing session is saved on this device. Please retry restoring it when the server is available. No new account was created."

        case .noRefreshToken:
            return "No refresh token available. Please log in again."

        }
    }
}

extension APIError {
    var requiresSubscription: Bool {
        switch self {
        case .backend(let status, _, _), .httpError(let status, _): return status == 402
        default: return false
        }
    }
    var isTransient: Bool {
        switch self {
        case .networkError: return true
        case .backend(let status, _, _), .httpError(let status, _): return status >= 500 || status == 429
        default: return false
        }
    }
}

struct BackendErrorDetail: Decodable {
    let code: String?
    let message: String
    enum CodingKeys: String, CodingKey { case detail }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? container.decode(String.self, forKey: .detail) {
            code = nil; message = text
        } else if let structured = try? container.decode(Structured.self, forKey: .detail) {
            code = structured.code; message = structured.message
        } else {
            let errors = try container.decode([Validation].self, forKey: .detail)
            code = "validation_error"; message = errors.map(\.msg).joined(separator: "\n")
        }
    }
    private struct Structured: Decodable { let code: String; let message: String }
    private struct Validation: Decodable { let msg: String }
}
