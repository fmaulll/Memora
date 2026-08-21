import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized

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

        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .unauthorized:
            return "Your session has expired. Please log in again."
        }
    }
}