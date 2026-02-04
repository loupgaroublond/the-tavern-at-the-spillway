# Handoff: Tavern SDK Integration

## Current State
The Tavern app works. Jake responds to messages. MCP tools are registered (summon_servitor, dismiss_servitor). 156 unit tests + 14 SDK live integration tests pass.

## Critical Bug Discovery

**Apostrophes in `--system-prompt` cause 60-second timeouts.**

### Reproduction
Any apostrophe (`'`) in the system prompt passed to ClodeMonster SDK causes a timeout:
- `"Say OK."` → works (2s)
- `"Don't"` → timeout (60s)
- `"It's fine."` → timeout (60s)

### Root Cause
`ClodeMonster/NativeClaudeCodeSDK/Sources/ClaudeCodeSDK/Transport/ProcessTransport.swift:171`:
```swift
process.arguments = ["-l", "-c", command]
```

The SDK joins CLI arguments into a single string (including `--system-prompt "..."`) then passes it to `zsh -l -c`. Apostrophes in the prompt break shell parsing.

### Evidence
Test file with isolation tests: `Tavern/Tests/TavernTests/SDKLiveIntegrationTests.swift`
- `testSummonWordInSystemPromptCausesTimeout` - demonstrates the bug
- `testIsolateTimeoutPhrase` - proves apostrophe is the cause

### Workaround Applied
Jake's system prompt in `Tavern/Sources/TavernCore/Agents/Jake.swift` has all apostrophes removed:
- "You're" → "You are"
- "Don't" → "Do not"
- "That's" → "That is"

Comment documents this at line 51-52.

## To File Bug in ClodeMonster

**Title:** Apostrophes in system prompt cause 60s timeout due to shell escaping

**Body:**
```
When --system-prompt contains apostrophes, the query times out after 60 seconds.

Reproduction:
- System prompt: "Don't do anything."
- Any MCP server registered
- Query never completes, times out at 60s

Root cause: ProcessTransport.swift:171 passes command string to `zsh -l -c`.
The command includes `--system-prompt "Don't..."` which breaks shell parsing.

Fix options:
1. Use Process.arguments array directly instead of shell string
2. Properly escape the command string for shell
3. Use single quotes with escaped inner quotes
```

## To Fix in ClodeMonster

The fix is in `ProcessTransport.swift`. Instead of:
```swift
let command = ([cliPath] + arguments).joined(separator: " ")
// ...
process.arguments = ["-l", "-c", command]
```

Either:
1. **Best:** Don't use shell - set `process.executableURL` directly to claude and use `process.arguments` array
2. **Alternatively:** Properly shell-escape the command string before passing to zsh

## Files Changed This Session
- `Tavern/Sources/TavernCore/Agents/Jake.swift` - apostrophe-free system prompt
- `Tavern/Sources/TavernCore/MCP/TavernMCPServer.swift` - MCP tools
- `Tavern/Tests/TavernTests/SDKLiveIntegrationTests.swift` - 14+ live tests
- MortalAgent → Servitor rename throughout

## Quick Verify
```bash
cd /Users/yankee/Documents/Projects/the-tavern-at-the-spillway
swift test --filter SDKLiveIntegrationTests  # All should pass
redo Tavern/run  # App should work, Jake should respond
```
