# Transcript: SDK Migration & Session Storage Architecture
**Date:** 2026-02-01

---

## Part 1: ClodeMonster SDK Migration

*Session continued from previous context (compacted). Migration from local ClaudeCodeSDK fork to ClodeMonster's NativeClaudeCodeSDK was completed.*

**[C]** Key API changes in the migration:

| Old SDK (Protocol-based) | New SDK (Static function) |
|--------------------------|---------------------------|
| `ClaudeCode` protocol with `runSinglePrompt()` | `ClaudeCode.query(prompt:options:)` |
| Dependency injection via protocol | No injection point - static function |
| `ClaudeCodeResult` enum (.json/.text/.stream) | `ClaudeQuery` (AsyncSequence<StdoutMessage>) |
| `ResultMessage.sessionId` | `query.sessionId` (async property) |
| `ClaudeCodeConfiguration` + `ClaudeCodeOptions` | Unified `QueryOptions` |

**Testing implications:** Without dependency injection, tests that previously mocked Claude responses can't work the same way. Tests requiring mocking are marked TODO.

---

## Part 2: Jake's JSON Response Format

**[U]** can you explain what's the difference between jake's logs and other logs? is jake's doing json inside json?

**[C]** Yes, exactly. Here's what's happening:

**Jake's design uses JSON for tool actions:**

Jake's system prompt explicitly tells him to respond in JSON format:
```json
{"message": "your response", "spawn": {"assignment": "task", "name": "optional"}}
```

This lets the app detect actions (like spawning agents) by parsing his responses. The `JakeToolHandler` extracts the message for display and executes any embedded actions.

**Other agents just return plain text** — they don't need structured responses for orchestration.

**The storage situation:**

```
Claude's session storage (JSONL file):
┌─────────────────────────────────────────────────────────────┐
│ {"type":"assistant","message":{"content":[{"text":"..."}]}} │  ← JSONL wrapper
└─────────────────────────────────────────────────────────────┘
                                                    │
                                                    ▼
                                        For regular agent:
                                        "Here's my plain text response"

                                        For Jake:
                                        "{\"message\":\"Here's my response\"}"
                                                    │
                                                    ▼
                                        JSON inside the JSONL content!
```

So yes, it's JSON-in-JSON. Claude's native storage wraps everything in JSONL, and Jake's actual content is *also* JSON.

**Live messages worked** because `JakeToolHandler.processResponse()` parses Jake's JSON before displaying.

**Restored history broke** because `loadSessionHistory()` pulled the raw content from storage without parsing Jake's JSON format.

The fix adds that same JSON parsing when loading Jake's historical messages.

---

## Part 3: Session Storage Forensics

*User triggered a session error when opening a project. Investigation followed.*

**[U]** i just triggered a session issue, can we go see what happened there?

**[C]** *From logs:*
```
Session 'b9f78ee4-5a36-4a58-9b95-7fbc15115470' appears corrupt:
The operation couldn't be completed. (ClaudeCodeSDK.TransportError error 1.)
```

**[U]** can you also check the archives in .claude?

**[C]** *Session file found in archives:*
```
~/.claude/session-archives/-Users-yankee-Documents-Projects-the-monkey/b9f78ee4-...jsonl
```

The session was archived (user's backup system preserved it) but deleted from `~/.claude/projects/` (Claude's 30-day auto-cleanup).

**[U]** so when the app opened up, where did it get the session history itself that it's displaying?

**[T]** *That's a great question. The user is pointing out an inconsistency - if the session file doesn't exist in `~/.claude/projects/`, how is Tavern displaying the session history at all?*

___

**[S]** This forensic investigation revealed a critical architectural distinction:

### Two Separate Operations with Different Requirements

**1. Loading session history (display-only)**

Tavern reads the JSONL file directly to show past conversation:
```
ChatViewModel.loadSessionHistory()
→ SessionStore.loadJakeSessionHistory()
→ ClaudeNativeSessionStorage.getMessages()
→ directly parses ~/.claude/projects/.../session.jsonl
```

This is purely read-only — no Claude API involvement.

**2. Resuming a session (continuing conversation)**

When sending a new message, Claude CLI needs to resume the session with Anthropic's servers:
```
Jake.send()
→ ClaudeCode.query(options.resume = sessionId)
→ SDK spawns: claude --resume b9f78ee4-...
→ Claude CLI exits with code 1
```

This requires both the local session file AND server-side session state.

### Why This Matters

- **History loading** works with just the local JSONL file
- **Resume** requires coordination between local state and Anthropic's servers
- A session can be **"displayable" but not "resumable"** if server-side state is gone
- The archives preserve local forensics but can't resurrect server-side session state

This explains why history displays correctly (local file exists) but resume fails with TransportError (server-side session expired).

### Session Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    Session Lifecycle                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  LOCAL STATE                    SERVER STATE                     │
│  ~/.claude/projects/            Anthropic's servers              │
│  ┌─────────────────┐            ┌─────────────────┐              │
│  │ session.jsonl   │            │ Session context │              │
│  │ (transcript)    │            │ (resumable)     │              │
│  └────────┬────────┘            └────────┬────────┘              │
│           │                              │                       │
│           │  30-day retention            │  Server-side TTL      │
│           │  (Claude auto-cleanup)       │  (unknown duration)   │
│           ▼                              ▼                       │
│  ┌─────────────────┐            ┌─────────────────┐              │
│  │ Archives        │            │ Expired/deleted │              │
│  │ (user backup)   │            │ (unrecoverable) │              │
│  └─────────────────┘            └─────────────────┘              │
│                                                                  │
│  History display: needs only local file                          │
│  Session resume: needs BOTH local file AND server state          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Changes

Files modified in this session:

1. **Package.swift** - SDK dependency path, added xcassets resources
2. **ChatView.swift** - Fixed deprecated `onChange(of:perform:)` API
3. **ChatViewModel.swift** - Added `parseJakeMessage()` to handle Jake's JSON in history
4. **Deleted duplicate icon files** - iCloud sync artifacts with " 2" suffix
