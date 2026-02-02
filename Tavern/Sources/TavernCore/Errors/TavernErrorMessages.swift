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

        // Handle ClodeMonster QueryError
        if let queryError = error as? QueryError {
            return message(for: queryError)
        }

        // Handle ClodeMonster SessionError
        if let sessionError = error as? SessionError {
            return message(for: sessionError)
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

    /// Convert ClodeMonster QueryError to an informative message
    public static func message(for error: QueryError) -> String {
        switch error {
        case .launchFailed(let reason):
            if reason.lowercased().contains("not found") || reason.lowercased().contains("no such file") {
                return """
                    Claude Code isn't installed on this machine.
                    You'll need to run: npm install -g @anthropic/claude-code
                    (Jake can't do his thing without it!)
                    """
            }
            return """
                Couldn't start the Claude process.
                Make sure Claude Code is installed and accessible.
                (Error: \(reason))
                """

        case .mcpConfigFailed(let reason):
            return """
                MCP configuration problem.
                \(reason)
                """

        case .invalidOptions(let reason):
            return """
                Configuration problem — something's not set up right.
                \(reason)
                """
        }
    }

    /// Convert ClodeMonster SessionError to an informative message
    public static func message(for error: SessionError) -> String {
        switch error {
        case .sessionClosed:
            return """
                The session was closed unexpectedly.
                Try starting a new conversation.
                """

        case .notInitialized:
            return """
                Session wasn't initialized properly.
                This is a bug — try again.
                """

        case .initializationFailed(let reason):
            return """
                Couldn't initialize the session.
                \(reason)
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
