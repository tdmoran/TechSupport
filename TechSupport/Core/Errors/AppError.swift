import Foundation

enum AppError: LocalizedError, Equatable {
    // API errors
    case apiKeyMissing
    case apiRateLimited(retryAfterSeconds: Int)
    case apiServerError(statusCode: Int, message: String)
    case apiNetworkError(String)
    case apiResponseInvalid(detail: String)

    // Diagnostic errors
    case diagnosticCommandFailed(command: String, detail: String)
    case diagnosticCommandNotAllowed(command: String)
    case diagnosticTimeout(command: String)

    // System monitor errors
    case systemMonitorUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "Anthropic API key is not configured."
        case .apiRateLimited(let seconds):
            return "Rate limited. Please wait \(seconds) seconds."
        case .apiServerError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .apiNetworkError(let detail):
            return "Network error: \(detail)"
        case .apiResponseInvalid(let detail):
            return "Unexpected API response: \(detail)"
        case .diagnosticCommandFailed(let command, let detail):
            return "Diagnostic '\(command)' failed: \(detail)"
        case .diagnosticCommandNotAllowed(let command):
            return "Command '\(command)' is not in the allowed list."
        case .diagnosticTimeout(let command):
            return "Diagnostic '\(command)' timed out."
        case .systemMonitorUnavailable(let detail):
            return "System monitor unavailable: \(detail)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .apiKeyMissing:
            return "Open Settings to add your Anthropic API key."
        case .apiRateLimited:
            return "The request will retry automatically."
        case .apiServerError:
            return "This is usually temporary. Try again in a moment."
        case .apiNetworkError:
            return "Check your internet connection and try again."
        case .apiResponseInvalid:
            return "Try switching to a different AI model in Settings."
        case .diagnosticCommandFailed:
            return "The diagnostic may require different permissions."
        case .diagnosticCommandNotAllowed:
            return "Only predefined safe commands can be executed."
        case .diagnosticTimeout:
            return "The command took too long. Try again or check system load."
        case .systemMonitorUnavailable:
            return "Some metrics may not be available on this hardware."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .apiRateLimited, .apiServerError, .apiNetworkError:
            return true
        default:
            return false
        }
    }
}
