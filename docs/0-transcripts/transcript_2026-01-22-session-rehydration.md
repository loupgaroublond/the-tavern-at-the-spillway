# Transcript: Session History Rehydration

**Date:** 2026-01-22
**Session:** Technical implementation — Persisting and restoring chat history across app restarts


## Context

After implementing session persistence (Jake remembers his session ID across app restarts), we discovered that the chat UI would be empty on relaunch. Claude remembered the conversation context, but the user couldn't see their previous messages. This session implemented full session history rehydration using the ClaudeCodeSDK's native session storage capabilities.


## The Journey

### Phase 1: Diagnosing the Blank Chat Issue

**[U]** Noticed that relaunching the app resulted in a blank chat, even though Jake's session ID was persisted and Claude remembered the context.

**[T]** *The session ID was being saved and restored via UserDefaults, so Claude CLI could continue the conversation. But the actual message history wasn't being displayed in the UI because we were only saving the session ID, not the messages themselves.*

**[C]** Investigated two options:
1. Persist messages locally (save/load from UserDefaults or disk)
2. Fetch history from Claude (if the CLI provides session history)

Discovered that the ClaudeCodeSDK has `ClaudeNativeSessionStorage` with a `getMessages(sessionId:projectPath:)` method that reads from Claude's native `.jsonl` session files.


### Phase 2: The Project Path Problem

**[C]** Attempted to load session history but discovered the issue: we were only saving `sessionId`, not `projectPath`. Claude stores sessions in directories named after the project's working directory.

**[T]** *Claude's session files live at `~/.claude/projects/<encoded-path>/<session-id>.jsonl`. Without knowing the project path, we can't locate the session file.*

**[C]** Updated `SessionStore` to save both `sessionId` and `projectPath`:
```swift
func saveJakeSession(sessionId: String, projectPath: String) {
    defaults.set(sessionId, forKey: jakeSessionIdKey)
    defaults.set(projectPath, forKey: jakeProjectPathKey)
}
```

Updated `Jake.swift` to save the project path from `backend.configuration.workingDirectory` when saving session.


### Phase 3: Loading Session History

**[C]** Added `SessionStore.loadJakeSessionHistory()` that:
1. Loads saved session ID and project path
2. Uses `ClaudeNativeSessionStorage().getMessages()` to read the JSONL
3. Converts `ClaudeStoredMessage` → `ChatMessage` for the UI

Updated `ChatViewModel.init()` to load history on startup for Jake.

**[S]** At this point, the architecture became clear: we're not duplicating storage. Claude's JSONL files are the source of truth, and we're reading from them on startup.


### Phase 4: The Content Block Parsing Bug

**[U]** After implementation, noticed that only user messages loaded — assistant messages were missing.

**[C]** Investigated and found the root cause in `ClaudeSessionModels.swift`:

**The Problem:**
- User messages have `content` as a String: `"Hello"`
- Assistant messages have `content` as an Array: `[{"type":"text","text":"Hello"}]`

The `ContentItem` struct's Codable decoder was incorrectly nested, expecting:
```json
{"type": {"text": "Hello"}}
```

But the actual JSON structure is:
```json
{"type": "text", "text": "Hello"}
```

**[T]** *This is a classic Codable bug where Swift's synthesized decoder doesn't match the actual JSON structure. The `ContentItem` needed custom decoding logic.*

**[C]** Rewrote `ContentItem` to decode directly from the flat JSON structure with proper handling for multiple content types:
- `text` — Regular text content
- `tool_use` — Tool invocation with input parameters
- `tool_result` — Tool execution results
- `other` — Unknown types (forward compatibility)


### Phase 5: The Path Encoding Mystery

**[C]** Created integration tests to verify the fix, but tests failed with "session file not found."

**[T]** *The path encoding was subtly wrong. The SDK's `encodeProjectPath()` was producing different output than Claude CLI's actual encoding.*

**[C]** Discovered two issues:

1. **Symlink resolution:** macOS has `/var` as a symlink to `/private/var`. The SDK wasn't resolving symlinks before encoding, but Claude CLI was.

2. **Underscore replacement:** Claude CLI replaces underscores with dashes in project names (e.g., `test_project` → `test-project`).

Fixed `ClaudeNativeSessionStorage.swift` to use Darwin's `realpath()` for proper path resolution:
```swift
private func resolvePath(_ path: String) -> String {
    guard let resolved = realpath(path, nil) else {
        return path
    }
    defer { free(resolved) }
    return String(cString: resolved)
}
```

Updated `encodeProjectPath()` to match Claude CLI's exact encoding behavior.


### Phase 6: Integration Tests

**[C]** Created `SessionStorageIntegrationTests.swift` with end-to-end tests that:
1. Create real sessions via Claude CLI (using `claude chat --working-directory`)
2. Send user and assistant messages
3. Verify session files are created in the correct location
4. Verify the SDK can parse and rehydrate both message types

**[S]** These tests serve as regression protection — if Claude CLI changes its format or the SDK's parsing breaks, we'll know immediately.


### Phase 7: The Blank Lines Mystery

**[U]** After the fixes, session history loaded successfully, but there were blank lines in the chat where tool use and tool results should appear.

**[C]** Investigated and discovered the issue: `ContentItem.displayText` was only extracting text from `text` type items. Tool use and tool result content was being ignored, resulting in empty strings.

**[T]** *The chat UI has existing infrastructure for rendering different content block types (MessageType enum with cases for text, toolUse, toolResult). But the SDK was throwing away that structure and flattening everything to plain text.*


### Phase 8: Preserving Content Block Structure

**[C]** Updated the SDK to preserve content block structure:

1. **Added `StoredContentBlock` enum** to `ClaudeSessionModels.swift`:
```swift
public enum StoredContentBlock: Codable, Sendable {
    case text(String)
    case toolUse(name: String, input: String)
    case toolResult(content: String, isError: Bool)
}
```

2. **Updated `ClaudeStoredMessage`** to include `contentBlocks: [StoredContentBlock]`

3. **Added conversion method** `ContentItem.toStoredBlock()` that:
   - Extracts text from `text` items
   - Parses tool name and input JSON from `tool_use` items
   - Extracts result content and error flag from `tool_result` items

4. **Updated parser** to populate `contentBlocks` array

5. **Updated `ChatViewModel`** to convert stored blocks to `MessageType`:
```swift
for block in message.contentBlocks {
    switch block {
    case .text(let text):
        messages.append(ChatMessage(..., type: .text))
    case .toolUse(let name, let input):
        messages.append(ChatMessage(..., type: .toolUse(name: name, input: input)))
    case .toolResult(let content, let isError):
        messages.append(ChatMessage(..., type: .toolResult(content: content, isError: isError)))
    }
}
```


### Phase 9: Parsing Tool Input and Error Flags

**[U]** Tool use blocks were now visible, but the `input` field was empty.

**[C]** The `tool_use` content blocks in the JSONL have an `input` field containing a JSON object with the tool's parameters:
```json
{
  "type": "tool_use",
  "id": "toolu_...",
  "name": "AskUserQuestion", 
  "input": {"question": "Should I answer questions?"}
}
```

Updated `ItemType` to parse the `input` field:
```swift
case toolUse(name: String, input: [String: Any])
```

Added pretty-printing when converting to `StoredContentBlock`:
```swift
let inputData = try JSONSerialization.data(withJSONObject: input)
let inputString = String(data: inputData, encoding: .utf8) ?? ""
return .toolUse(name: name, input: inputString)
```

**[C]** Also noticed that `tool_result` blocks have an `is_error` boolean flag that wasn't being captured. Updated the decoder to extract it:
```swift
case toolResult(content: String, isError: Bool)
```


### Phase 10: Build System Refinement

**[U]** "Now transcribe and then commit."

**[C]** During the session, also made a small fix to the redo build system:

Changed `Tavern/run.do` to always rebuild before launching:
```bash
redo Tavern/build  # Always rebuild
redo Tavern/kill   # Kill existing instances
```

Previously used `redo-ifchange` which only rebuilt when dependencies changed, causing confusion when testing.


## Technical Details

### Files Modified

#### SDK Changes (LocalPackages/ClaudeCodeSDK/)

1. **Sources/.../Storage/ClaudeSessionModels.swift**
   - Rewrote `ContentItem` Codable decoder to handle flat JSON structure
   - Added `StoredContentBlock` enum for preserving structure
   - Added `contentBlocks` array to `ClaudeStoredMessage`
   - Added parsing for tool use input (JSON object → string)
   - Added parsing for tool result error flag

2. **Sources/.../Storage/ClaudeNativeSessionStorage.swift**
   - Added `resolvePath()` using Darwin's `realpath()`
   - Fixed `encodeProjectPath()` to resolve symlinks before encoding
   - Fixed underscore-to-dash replacement to match Claude CLI

3. **Sources/.../Logging/TavernLogger.swift**
   - Added `debugError()`, `debugInfo()`, `debugLog()` methods
   - Use `.public` privacy in DEBUG builds (visible in Console.app)
   - Use `.private` privacy in release builds (secure)

4. **Sources/.../Backend/HeadlessBackend.swift**
   - Added verbose error output with actual CLI output in DEBUG builds
   - Helps diagnose "no result message found" errors

#### App Changes (Tavern/)

5. **Sources/TavernCore/Persistence/SessionStore.swift**
   - Added `jakeProjectPathKey` constant
   - Updated `saveJakeSession()` to accept and save project path
   - Updated `loadJakeSession()` to return both session ID and project path
   - Added `loadJakeSessionHistory()` to read JSONL via SDK

6. **Sources/TavernCore/Agents/Jake.swift**
   - Updated to save project path from `backend.configuration.workingDirectory`
   - Used `debugError()` for visible logging in debug builds

7. **Sources/TavernCore/Chat/ChatViewModel.swift**
   - Added session history loading on init for Jake
   - Added conversion logic from `StoredContentBlock` → `MessageType`
   - Filters out empty blocks (no more blank lines)

8. **Sources/TavernCore/Errors/TavernError.swift** (new file)
   - Added `TavernError.sessionCorrupt(sessionId:underlyingError:)` case
   - Surfaced to user when session resume fails

9. **Sources/TavernCore/Errors/TavernErrorMessages.swift**
   - Added handler for `TavernError` with user-friendly messages

10. **Sources/Tavern/Views/ChatView.swift**
    - Added `SessionRecoveryBanner` component with "Start Fresh" button
    - Banner appears when corrupt session is detected

#### Tests

11. **Tests/TavernCoreTests/SessionStorageIntegrationTests.swift** (new file)
    - End-to-end tests creating real Claude sessions
    - Verifies session files are created correctly
    - Verifies SDK can parse and rehydrate messages
    - 3 integration tests, all passing

12. **Tests/TavernCoreTests/SDKDiagnosticTests.swift**
    - Updated to verify JSON format now works (previously documented bug)

#### Build System

13. **Tavern/run.do**
    - Changed to always rebuild before launching (removed `redo-ifchange`)


### Test Results

**All 173 tests pass**, including:
- 3 new integration tests for session rehydration
- Updated diagnostic test for fixed JSON parsing
- All existing unit tests

**Build**: Succeeded with zero warnings


## Key Insights

### 1. Single Source of Truth
Rather than duplicating storage, we read from Claude's native JSONL files. The session files are the authoritative record — we just parse them on startup.

### 2. Path Encoding is Subtle
macOS symlinks (`/var` → `/private/var`) and Claude CLI's character replacement rules (underscores → dashes) must be matched exactly, or session files can't be found.

### 3. Content Structure Matters
Flattening content to plain text loses important structure. Tool use and tool results are first-class content types that need proper rendering in the UI.

### 4. Integration Tests Prevent Regression
Creating real sessions via Claude CLI and verifying end-to-end parsing catches bugs that unit tests on mocked data would miss.

### 5. Debug Logging Must Be Visible
macOS's privacy-by-default for `os.log` makes debugging nearly impossible. Using `.public` privacy in DEBUG builds is essential for diagnosing issues.


## Principles Applied

### Informative Error Principle
Session corruption is now surfaced to the user with a clear message and recovery option ("Start Fresh" button), rather than silently failing.

### Instrumentation Principle  
Added debug logging throughout the session loading flow so issues can be diagnosed from logs alone, without needing screenshots or reproduction steps.

### Sum Type Error Design
`TavernError.sessionCorrupt` is a specific error case, not a generic catch-all. Forces explicit handling in the UI layer.

### Autonomous Testing Principle
Integration tests run headlessly via `swift test`, creating real Claude sessions and verifying parsing works end-to-end.


## What Now Works

1. **Session persistence** — Jake remembers both session ID and project path across restarts
2. **History rehydration** — Chat UI displays all previous messages on relaunch
3. **Content block rendering** — Text, tool use, and tool results all display correctly
4. **Error handling** — Corrupt sessions surface to user with recovery option
5. **Debug visibility** — Logs are visible in Console.app during development


## Open Questions

None — the feature is complete and tested.


---

*The spillway flows forward, but Jake remembers.*
