import Foundation
import ClodKit

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

        // Handle ClodKit QueryError
        if let queryError = error as? QueryError {
            return message(for: queryError)
        }

        // Handle ClodKit SessionError
        if let sessionError = error as? SessionError {
            return message(for: sessionError)
        }

        // Handle ClodKit ControlProtocolError
        if let controlError = error as? ControlProtocolError {
            return message(for: controlError)
        }

        // Handle ClodKit TransportError
        if let transportError = error as? TransportError {
            return message(for: transportError)
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

    /// Convert ClodKit QueryError to an informative message
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

    /// Convert ClodKit SessionError to an informative message
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

    /// Convert ClodKit ControlProtocolError to an informative message
    public static func message(for error: ControlProtocolError) -> String {
        switch error {
        case .timeout(let requestId):
            return """
                Request timed out waiting for Claude.
                Claude might be overloaded or there's a connection issue.
                (Request: \(requestId.prefix(8))...)
                """

        case .cancelled(let requestId):
            return """
                Request was cancelled.
                (Request: \(requestId.prefix(8))...)
                """

        case .responseError(let requestId, let message):
            return """
                Claude returned an error: \(message)
                (Request: \(requestId.prefix(8))...)
                """

        case .unknownSubtype(let subtype):
            return """
                Unexpected response type from Claude: \(subtype)
                This might be a version mismatch. Try updating Claude Code.
                """

        case .invalidMessage(let details):
            return """
                Invalid message from Claude process.
                \(details)
                Try restarting the app.
                """
        }
    }

    /// Convert ClodKit TransportError to an informative message
    public static func message(for error: TransportError) -> String {
        switch error {
        case .notConnected:
            return """
                Not connected to Claude.
                The Claude process isn't running. Try restarting the app.
                """

        case .writeFailed(let reason):
            return """
                Couldn't send message to Claude.
                The Claude process may have crashed.
                \(reason)
                """

        case .processTerminated(let exitCode):
            return """
                Claude process terminated unexpectedly.
                Exit code: \(exitCode)
                Try restarting the app.
                """

        case .launchFailed(let reason):
            return """
                Couldn't start Claude.
                Make sure Claude Code is installed: npm install -g @anthropic/claude-code
                \(reason)
                """

        case .closed:
            return """
                Connection to Claude was closed.
                Try starting a new conversation.
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
