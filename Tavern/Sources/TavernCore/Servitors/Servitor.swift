import Foundation

// MARK: - Provenance: REQ-AGT-005, REQ-AGT-010, REQ-ARCH-004

// ServitorState has moved to TavernKit.

/// Protocol defining the common interface for all servitors in the Tavern
public protocol Servitor: AnyObject, Identifiable, Sendable {

    /// Unique identifier for this servitor
    var id: UUID { get }

    /// Display name for this servitor
    var name: String { get }

    /// Current state of the servitor
    var state: ServitorState { get }

    /// The servitor's current session mode (plan, normal, acceptEdits, etc.)
    var sessionMode: TavernKit.PermissionMode { get set }

    /// Send a message to this servitor and get a response (batch mode)
    /// - Parameter message: The message to send
    /// - Returns: The servitor's response
    func send(_ message: String) async throws -> String

    /// Send a message and receive a stream of events (streaming mode)
    /// - Parameter message: The message to send
    /// - Returns: Tuple of (event stream, cancel closure)
    func sendStreaming(_ message: String) -> (stream: AsyncThrowingStream<StreamEvent, Error>, cancel: @Sendable () -> Void)

    /// Reset the servitor's conversation state
    func resetConversation()
}
