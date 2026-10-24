import Foundation

enum AppError: Error, Equatable, Sendable {
    case noInternet
    case timeout
    case rateLimited
    case invalidInput
    case invalidResponse(String)
    case apiError(code: Int, details: String)
    case unknown(String)

    var message: String {
        switch self {
        case .noInternet:
            "No internet connection. Check your network and try again."
        case .timeout:
            "The request timed out. Please try again."
        case .rateLimited:
            "Too many requests. Please wait a moment and try again."
        case .invalidInput:
            "Text must be between 100 and 10,000 characters."
        case .invalidResponse(let details):
            "Received an unexpected response: \(details)"
        case .apiError(let code, let details):
            "Request failed (\(code)): \(details)"
        case .unknown(let details):
            "Something went wrong: \(details)"
        }
    }
}
