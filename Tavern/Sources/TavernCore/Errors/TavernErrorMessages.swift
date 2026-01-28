import Foundation
import ClaudeCodeSDK

/// Maps errors to informative, Jake-style messages for users
/// Every error the user sees should be expected, specific, and actionable
public enum TavernErrorMessages {

    /// Convert any error to an informative message for the user
    /// - Parameter error: The error that occurred
    /// - Returns: A user-friendly message explaining what happened
    public static func message(for error: Error) -> String {
        // Handle TavernError specifically
        if let tavernError = error as? TavernError {
            return message(for: tavernError)
        }

        // Handle ClaudeCodeError specifically
        if let claudeError = error as? ClaudeCodeError {
            return message(for: claudeError)
        }

        // Handle URL/network errors
        if let urlError = error as? URLError {
            return message(for: urlError)
        }

        // Handle NSError (many system errors)
        let nsError = error as NSError

        // Check for common system error domains
        if nsError.domain == NSURLErrorDomain {
            return networkErrorMessage(code: nsError.code)
        }

        if nsError.domain == NSPOSIXErrorDomain {
            return posixErrorMessage(code: nsError.code, description: nsError.localizedDescription)
        }

        // Fallback - but log it so we can add specific handling
        return unknownErrorMessage(error: error)
    }

    /// Convert ClaudeCodeError to an informative message
    public static func message(for error: ClaudeCodeError) -> String {
        switch error {
        case .notInstalled:
            return """
                Claude Code isn't installed on this machine.
                You'll need to run: npm install -g @anthropic/claude-code
                (Jake can't do his thing without it!)
                """

        case .executionFailed(let details):
            // Parse the details for more specific messages
            let lower = details.lowercased()

            if lower.contains("api key") || lower.contains("unauthorized") || lower.contains("authentication") {
                return """
                    Authentication problem — Claude doesn't recognize your API key.
                    Check that ANTHROPIC_API_KEY is set correctly in your environment.
                    """
            }

            if lower.contains("rate limit") || lower.contains("too many requests") {
                return """
                    Claude's asking us to slow down — rate limit hit.
                    Give it a minute and try again. The Tavern's not going anywhere.
                    """
            }

            if lower.contains("timeout") || lower.contains("timed out") {
                return """
                    Claude took too long to respond — request timed out.
                    Could be a complex request, could be Claude having a moment.
                    Try again, maybe with a simpler ask.
                    """
            }

            if lower.contains("connection") || lower.contains("network") {
                return """
                    Network hiccup — couldn't reach Claude.
                    Check your internet connection and try again.
                    """
            }

            // Generic execution failure
            return "Claude ran into a problem: \(details)"

        case .invalidOutput(let details):
            return """
                Claude sent back something unexpected.
                This is usually temporary — try again.
                (Technical: \(details))
                """

        case .jsonParsingError(let underlyingError):
            // Extract details from the underlying error for debugging
            let details = underlyingError.localizedDescription
            return """
                Claude's response couldn't be parsed.
                This usually means something went wrong on Claude's end, or
                there's an environment issue (PATH, permissions, etc.).

                Try again. If it keeps happening, check Console.app for
                logs from "ClaudeCode" to see what Claude actually returned.

                (Technical: \(details))
                """

        case .cancelled:
            return "Request cancelled. The Tavern stands ready when you are."

        case .timeout(let duration):
            return """
                Request timed out after \(Int(duration)) seconds.
                Claude might be busy or your request might be too complex.
                Try again, or break it into smaller pieces.
                """

        case .rateLimitExceeded(let retryAfter):
            if let seconds = retryAfter {
                return """
                    Rate limit hit — Claude needs a breather.
                    Try again in \(Int(seconds)) seconds. The Tavern will wait.
                    """
            }
            return """
                Rate limit hit — Claude needs a breather.
                Give it a minute and try again.
                """

        case .networkError(let underlyingError):
            return """
                Network error — can't reach Claude right now.
                Check your internet connection.
                (Error: \(underlyingError.localizedDescription))
                """

        case .permissionDenied(let details):
            return """
                Permission denied — Claude can't do that.
                \(details)
                You might need to adjust your settings or permissions.
                """

        case .processLaunchFailed(let details):
            return """
                Couldn't start the Claude process.
                Make sure Claude Code is installed and accessible.
                (Error: \(details))
                """

        case .invalidConfiguration(let details):
            return """
                Configuration problem — something's not set up right.
                \(details)
                """
        }
    }

    /// Convert TavernError to an informative message
    public static func message(for error: TavernError) -> String {
        switch error {
        case .sessionCorrupt(let sessionId, _):
            return """
                Jake's previous session couldn't be resumed — it may be corrupt or expired.
                Session ID: \(sessionId)

                Click "Start Fresh" below to clear the old session and try again.
                """
        case .internalError(let message):
            return """
                Something unexpected happened inside the Tavern.
                \(message)

                Try again — if this keeps happening, it's a bug.
                """
        }
    }

    /// Convert URLError to an informative message
    public static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return """
                No internet connection.
                The Tavern needs wifi to talk to Claude.
                """

        case .timedOut:
            return """
                Request timed out — Claude's taking too long.
                Try again, or check your connection.
                """

        case .cannotFindHost, .cannotConnectToHost:
            return """
                Can't reach Claude's servers.
                Either they're down or your DNS is acting up.
                Try again in a bit.
                """

        case .networkConnectionLost:
            return """
                Connection dropped mid-request.
                Check your wifi and try again.
                """

        case .secureConnectionFailed:
            return """
                Secure connection failed.
                This might be a network security issue or certificate problem.
                """

        default:
            return """
                Network error: \(error.localizedDescription)
                Check your internet connection and try again.
                """
        }
    }

    // MARK: - Private Helpers

    private static func networkErrorMessage(code: Int) -> String {
        switch code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection. The Tavern needs wifi to reach Claude."
        case NSURLErrorTimedOut:
            return "Request timed out. Claude might be busy — try again."
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
            return "Can't reach Claude's servers. They might be down, or check your connection."
        default:
            return "Network error (code \(code)). Check your internet connection."
        }
    }

    private static func posixErrorMessage(code: Int, description: String) -> String {
        switch code {
        case 2: // ENOENT - No such file or directory
            return "Claude Code not found. Make sure it's installed: npm install -g @anthropic/claude-code"
        case 13: // EACCES - Permission denied
            return "Permission denied. Check that Claude Code has the right permissions."
        default:
            return "System error: \(description)"
        }
    }

    private static func unknownErrorMessage(error: Error) -> String {
        // Log this somewhere so we can add specific handling
        // For now, at least give the user SOMETHING useful
        let errorType = String(describing: type(of: error))
        let description = error.localizedDescription

        // Don't show useless "error N" messages
        if description.contains("error ") && description.contains(".") {
            return """
                Something unexpected happened.
                Try again, and if it keeps happening, let us know.
                (Technical: \(errorType))
                """
        }

        return """
            Something went wrong: \(description)
            Try again, and if it keeps happening, let us know.
            """
    }
}
