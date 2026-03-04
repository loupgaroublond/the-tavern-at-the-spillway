# Transcript: SDK Migration Design — Session Storage is Tavern-Specific

**Date:** 2026-02-02 01:00

---

## Part 1: The SDK Migration Question

**[U]** in /Users/yankee/Documents/Projects/ClodeMonster, we have a redo of the SDK. it's currently in development, so it's best if you just link the project to that folder directly. what would it take to switch to that sdk, in code as well?

**[T]** *The user is asking about migrating from the local ClaudeCodeSDK fork (in LocalPackages/) to ClodeMonster's NativeClaudeCodeSDK. I need to understand both APIs before answering.*

**[C]** I'll explore both the current SDK usage and the ClodeMonster SDK to understand what changes would be needed.

*Claude explored both SDKs in parallel and produced a comparison.*

**[C]** The issue is that Tavern needs two things from an SDK:

1. **Runtime communication** — sending messages to Claude and getting responses back
2. **Session history** — reading old conversations from `~/.claude/projects/` so chat history survives app restarts

ClodeMonster handles #1 beautifully — it has a modern async API for querying Claude. But it doesn't have #2 at all.

The current local fork includes ~500 lines of code that:
- Knows where Claude CLI stores session files (`~/.claude/projects/{project}/{session}.jsonl`)
- Parses the JSONL format
- Extracts content blocks (text, tool_use, tool_result) into Swift types
- Returns `ClaudeStoredMessage` arrays that ChatViewModel uses to populate the chat on launch

Without this, when you restart Tavern, the chat would be empty — even though Claude CLI still has the full conversation history on disk.

**The two options:**
- **Port to ClodeMonster** — Copy those ~500 lines into ClodeMonster. Then ClodeMonster becomes a complete SDK and Tavern just uses it normally.
- **Hybrid** — Keep using the storage code from somewhere, while using ClodeMonster for everything else.

---

**[U]** i'm not sure i fully understand the question, elaborate first, and then we can talk this out

**[C]** Yes, exactly. ClodeMonster is missing functionality that the current SDK (the local fork) has.

**What ClodeMonster can do:**
- Start a new conversation with Claude
- Resume an existing session by ID (pass `options.resume = sessionId`)
- Stream responses as an AsyncSequence
- Register hooks, MCP tools, permission callbacks

**What ClodeMonster cannot do:**
- Read the contents of past sessions from disk
- List what sessions exist for a project
- Load message history to display in UI

The current SDK has a class called `ClaudeNativeSessionStorage` that reads the JSONL files Claude CLI writes to `~/.claude/projects/`. Tavern uses this to populate the chat view when you open a project.

ClodeMonster can *continue* a session if you give it the session ID, but it can't *show you what happened* in that session. That's the gap.

---

**[U]** to clarify, you mean the sdk is missing some functionality?

**[C]** Correct. ClodeMonster handles live communication with Claude perfectly. But it has no concept of reading past sessions from disk.

---

**[U]** in that project, can you look at any specs and the vendored sdks? let's find out if this was functionality in the other sdks in the first place

**[T]** *Excellent instinct. The user is questioning whether session history reading was ever an SDK feature — or whether it was custom code added to the local fork specifically for Tavern. This would change whether ClodeMonster is "missing" something or simply implementing the spec correctly.*

**[C]** *Claude examined ClodeMonster's vendored SDK specifications.*

**[C]** This is clarifying. Looking at the vendored SDKs:

- `vendor/claude-agent-sdk-typescript/` — Official Anthropic TypeScript SDK
- `vendor/claude-agent-sdk-python/` — Official Anthropic Python SDK
- `CLAUDE_AGENT_SDK_API_SPEC.md` — Spec for the official SDK

The official SDK's Session Management (Section 14) only covers:
- **14.1** Getting session ID from init message
- **14.2** Resuming sessions via `resume` option
- **14.3** Fork vs resume behavior

**No session history loading.** No reading JSONL files from disk. No `getMessages()`.

The `ClaudeNativeSessionStorage` in the local fork was custom code written specifically for Tavern — it's not part of any official SDK. ClodeMonster is implementing parity with the official SDK, so it correctly doesn't have this.

**This means:**
1. ClodeMonster isn't "missing" anything — it matches the official spec
2. The session history loading is Tavern-specific functionality
3. It should live in Tavern, not in the SDK

---

**[U]** that gap analysis is out of date, belongs in archives or something

*[Tool use interrupted.]*

**[U]** sorry, wrong keypress, go do that plan

*Claude executed the migration plan.*

___

**[S]** This session established a critical architectural clarification with lasting implications:

### Session Storage is Tavern-Specific, Not SDK Functionality

The `ClaudeNativeSessionStorage` class — ~500 lines that reads JSONL files from `~/.claude/projects/` — was never part of any official Anthropic SDK. It was custom code added to the jamesrochabrun fork specifically for Tavern.

The official Anthropic SDKs (TypeScript, Python) have no concept of reading session history from disk. ClodeMonster correctly implements the official SDK spec and therefore also lacks this functionality.

**The consequence:** The migration from LocalPackages to ClodeMonster is architecturally cleaner than initially thought:

- **ClodeMonster** handles everything in the official SDK spec (runtime communication, session resume, hooks, MCP tools)
- **TavernCore** owns its own session history reading code — this is where it belongs

No need to add anything to ClodeMonster. Moving `ClaudeNativeSessionStorage` from `LocalPackages/ClaudeCodeSDK/` into `TavernCore/Persistence/` is the right call.

### API Transformation

| Old SDK (Protocol-based) | New SDK (Namespace) |
|--------------------------|---------------------|
| `ClaudeCode` protocol | `ClaudeCode` namespace |
| `runSinglePrompt()` | `ClaudeCode.query()` |
| `ClaudeCodeResult` enum | `AsyncSequence<StdoutMessage>` |
| `ResultMessage.sessionId` | `query.sessionId` (async) |
| Dependency injection via protocol | Static function (no injection) |

### Testability Tradeoff

The new API is cleaner but breaks the injection-based test approach. The old protocol let tests inject a `MockClaudeCode`. The new static `ClaudeCode.query()` has no injection point — tests that require mocked Claude responses become integration tests or need a protocol wrapper.

This is an explicit tradeoff: the official SDK design doesn't accommodate mocking at the SDK level. Any mock infrastructure must live at the Tavern level.
