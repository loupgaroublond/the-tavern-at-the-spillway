import Foundation
import Testing
import ClodKit
@testable import TavernCore
@testable import TavernKit

// MARK: - Provenance: REQ-SDK-002f

@Suite("Elicitation Support Tests", .timeLimit(.minutes(1)))
struct ElicitationTests {

    // MARK: - Callback Registration

    @Test("Elicitation callback built when handler configured")
    func elicitationCallbackRegistered() {
        let handler: ElicitationHandler = { _ in .decline }
        let messenger = LiveMessenger(elicitationHandler: handler)

        let callback = messenger.buildElicitationCallback()
        #expect(callback != nil)
    }

    @Test("No elicitation callback when no handler configured auto-declines")
    func noHandlerConfiguredReturnsNil() {
        let messenger = LiveMessenger()

        let callback = messenger.buildElicitationCallback()
        #expect(callback == nil)
    }

    // MARK: - Handler Response Transformation

    @Test("User accept with content transforms to SDK accept")
    func userCanAcceptWithValues() async throws {
        let handler: ElicitationHandler = { request in
            #expect(request.serverName == "test-server")
            #expect(request.message == "Enter your API key")
            return .accept(content: ["api_key": "sk-123"])
        }
        let messenger = LiveMessenger(elicitationHandler: handler)
        let callback = try #require(messenger.buildElicitationCallback())

        let sdkRequest = ElicitationRequest(
            serverName: "test-server",
            message: "Enter your API key",
            mode: "form"
        )
        let result = try await callback(sdkRequest)

        #expect(result.action == "accept")
        // Verify content was transformed to JSONValue
        if case .object(let dict) = result.content {
            if case .string(let value) = dict["api_key"] {
                #expect(value == "sk-123")
            } else {
                Issue.record("Expected string value for api_key")
            }
        } else {
            Issue.record("Expected object content in accept result")
        }
    }

    @Test("User accept without content transforms to SDK accept with nil content")
    func userCanAcceptWithoutContent() async throws {
        let handler: ElicitationHandler = { _ in .accept() }
        let messenger = LiveMessenger(elicitationHandler: handler)
        let callback = try #require(messenger.buildElicitationCallback())

        let sdkRequest = ElicitationRequest(serverName: "s", message: "m")
        let result = try await callback(sdkRequest)

        #expect(result.action == "accept")
        #expect(result.content == nil)
    }

    @Test("User decline transforms to SDK decline")
    func userCanDecline() async throws {
        let handler: ElicitationHandler = { _ in .decline }
        let messenger = LiveMessenger(elicitationHandler: handler)
        let callback = try #require(messenger.buildElicitationCallback())

        let sdkRequest = ElicitationRequest(serverName: "s", message: "m")
        let result = try await callback(sdkRequest)

        #expect(result.action == "decline")
        #expect(result.content == nil)
    }

    @Test("User cancel transforms to SDK cancel")
    func userCanCancel() async throws {
        let handler: ElicitationHandler = { _ in .cancel }
        let messenger = LiveMessenger(elicitationHandler: handler)
        let callback = try #require(messenger.buildElicitationCallback())

        let sdkRequest = ElicitationRequest(serverName: "s", message: "m")
        let result = try await callback(sdkRequest)

        #expect(result.action == "cancel")
        #expect(result.content == nil)
    }

    // MARK: - SDK Request Field Mapping

    @Test("All SDK request fields mapped to Tavern request")
    func sdkRequestFieldsMapped() async throws {
        let capturedBox = CapturedRequestBox()
        let handler: ElicitationHandler = { request in
            await capturedBox.set(request)
            return .decline
        }
        let messenger = LiveMessenger(elicitationHandler: handler)
        let callback = try #require(messenger.buildElicitationCallback())

        let sdkRequest = ElicitationRequest(
            serverName: "my-mcp-server",
            message: "Authenticate please",
            mode: "url",
            url: "https://auth.example.com",
            elicitationId: "elicit-42"
        )
        _ = try await callback(sdkRequest)

        let request = try #require(await capturedBox.value)
        #expect(request.serverName == "my-mcp-server")
        #expect(request.message == "Authenticate please")
        #expect(request.mode == "url")
        #expect(request.url == "https://auth.example.com")
        #expect(request.elicitationId == "elicit-42")
    }

    // MARK: - Config Wiring

    @Test("ClodSession.Config accepts elicitation handler")
    func configAcceptsHandler() {
        let handler: ElicitationHandler = { _ in .decline }
        let config = ClodSession.Config(
            systemPrompt: "Test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            elicitationHandler: handler,
            servitorName: "Test"
        )
        #expect(config.elicitationHandler != nil)
    }

    @Test("ClodSession.Config defaults elicitation handler to nil")
    func configDefaultsToNil() {
        let config = ClodSession.Config(
            systemPrompt: "Test",
            permissionMode: .plan,
            workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            servitorName: "Test"
        )
        #expect(config.elicitationHandler == nil)
    }
}

// MARK: - Test Helpers

/// Actor-isolated box for capturing values across `@Sendable` closures in tests.
private actor CapturedRequestBox {
    var value: TavernElicitationRequest?

    func set(_ request: TavernElicitationRequest) {
        value = request
    }
}
