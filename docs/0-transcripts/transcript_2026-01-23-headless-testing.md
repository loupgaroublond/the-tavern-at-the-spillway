# Transcript: Headless Debugging & Autonomous Testing Philosophy

**Date:** 2026-01-23
**Session:** Debugging strategy, testing methodology, autonomous test design


## Context

While implementing session history rehydration, debugging shifted from GUI-based investigation to headless integration testing. The user established a clear principle: the Tavern project requires autonomous, headless testing wherever possible.


## The GUI Debugging Anti-Pattern

**[U]** During session history rehydration work, Claude was using the GUI app to debug issues: relaunching manually, checking logs visually, hand-testing scenarios.

**[U]** "why are you doing this? apps always background. you need to find another way to instrument the app"

*[T] The problem: GUI apps run in the background and can't be reliably observed through manual testing. The solution: find a way to debug programmatically.*

**[C]** Switched to file-based debug logging at `/tmp/tavern_sdk_debug.log` instead of relying on Console.app and manual restarts.


## The Stubbed Test Fallacy

**[U]** "ok, so pause here for a moment. this is a perfect example of something you should be able to debug fully autonomously without the gui app, but from a headless mode. before you proceed any further, take some notes down on disk about where you're at, then go find a way to debug this in a headless mode, and then come back to fixing it"

*[T] The user is establishing a boundary: don't debug against stubbed test data. Create real end-to-end tests.*

**[U]** "no, the tests can work with stubbed jsonl files, but they should also work by literally creating a temp directory, running the app with claude at that for PWD, and then creating real sessions, and then trying to rehydrate them on second load. you must test literally every fucking thing thoroughly, headless, otherwise you're just testing your ability to parse your test cases"

*[T] This is the core principle being established. Stubbed tests are useful (they test the parser), but insufficient. Real integration tests must:*
1. *Create actual temp directories*
2. *Run real Claude CLI (not mocked)*
3. *Create real sessions*
4. *Verify rehydration works end-to-end*

**[U]** "stubs are good to test your parser itself, btw, so don't discount that technique, but today i need the end to end working"

*[T] Nuance: stubs are fine for unit testing the parser itself, but not as a substitute for integration tests.*


## The Philosophy

**Design Principles at Play:**

1. **Autonomous Testing Principle** — Tests must run without human interaction or visual observation. They must verify their own outcomes programmatically.

2. **End-to-End Over Unit** — For integrations with external systems (Claude CLI), unit tests with mocks are insufficient. Must test the actual integration.

3. **Repeatability** — Headless tests can run in CI/CD, in containers, or in any environment. GUI-based testing cannot.

4. **Instrumentation > Observation** — Code must emit verifiable signals (logs, file output, return values) that can be checked programmatically, not by looking at the screen.


## Implementation: SessionStorageIntegrationTests.swift

**[C]** Created end-to-end integration tests in `SessionStorageIntegrationTests.swift`:

```swift
func testCreateAndReadRealSession() async throws {
    // Check Claude CLI is available
    guard await isClaudeAvailable() else { throw XCTSkip("Claude CLI not available") }

    // Create temp directory with real working directory
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    // Run REAL Claude CLI to create a session
    let client = ClaudeCodeClient(workingDirectory: tempDir.path)
    let result = try await client.runSinglePrompt(
        prompt: "Say exactly: TEST_RESPONSE_123",
        outputFormat: .json,
        options: nil
    )

    // Verify session file was created
    let sessionPath = /* calculated path */
    XCTAssertTrue(FileManager.default.fileExists(atPath: sessionPath))

    // Verify SDK can read it back
    let storage = ClaudeNativeSessionStorage()
    let messages = try await storage.getMessages(sessionId: result.sessionId, projectPath: tempDir.path)
    XCTAssertGreater(messages.count, 0)
}
```

**Key aspects:**
- Uses real Claude CLI (not mocked)
- Creates real session files
- Tests the entire pipeline: creation → rehydration
- Verifies output programmatically (file existence, message count)
- No human observation required


## Test Results and Debugging

**[C]** Ran integration tests. Result: failed. SDK returned 0 messages despite session files existing.

**Debug output:**
```
Failed to parse: typeMismatch(ClaudeCodeSDK.ClaudeJSONLEntry.MessageContentValue,
Swift.DecodingError.Context(codingPath: [message, content],
debugDescription: "Expected String or [ContentItem]"))
```

*[T] The failure is specific and programmatically detectable. Because the test is headless, the problem can be reproduced reliably without manual steps.*

**[C]** Root cause found: The `MessageContentValue` Codable decoder in `ClaudeSessionModels.swift` fails to decode assistant message content arrays.

The test provides both the failure condition AND the exact path to the fix. This is the power of end-to-end integration tests.


## Contrast: GUI vs Headless Debugging

**GUI-Based Debugging:**
- Launch app manually
- Send a message
- Open Console.app
- Look for errors (or squint at redacted logs)
- Restart app, repeat

**Headless Debugging:**
- Run `swift test` (or similar)
- Get exact error: "typeMismatch at codingPath: [message, content]"
- Trace directly to the bug
- Fix and re-run test
- Repeat in seconds, not minutes


## The Honor System Commitment

The Tavern project has a stated principle: **Autonomous Testing Principle**.

*"Tests run without human interaction."*

This session reinforced that commitment:
- No GUI app relaunching for debugging
- No manual verification steps
- No "can you see if this works?" prompts
- Every scenario must be testable headlessly


## Files Affected

1. **`Tests/TavernCoreTests/SessionStorageIntegrationTests.swift`** (NEW)
   - End-to-end integration tests
   - Real Claude CLI, real sessions, real rehydration
   - Programmatic verification of outcomes

2. **`Tavern/LocalPackages/ClaudeCodeSDK/Sources/.../ClaudeSessionModels.swift`**
   - Contains the parsing bug that integration tests discovered
   - Needs fixing: `MessageContentValue` Codable decoder


## Key Takeaway

**Testing Strategy = Debugging Strategy**

When you design tests to be headless and autonomous, you create a system where:
1. Bugs are caught automatically and early
2. Debugging can happen programmatically (no human observation)
3. Fixes can be verified in seconds (no manual restart cycles)
4. The same tests run in CI/CD as in local development

This is the principle the user is enforcing across The Tavern project.
