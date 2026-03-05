# Session Management Analysis

## Current Architecture

### The Two Parallel Paths

```mermaid
graph TD
    subgraph "Active Path (Tile Architecture)"
        TP[TavernProject.initialize] --> CSM[ClodSessionManager]
        CSM --> WB[WindowBoard]
        WB --> CSP[ChatSocketPool]
        CSP --> CT[ChatTile]
        CT -->|sendStreaming| CSM
        CSM -->|servitorID == jake.id| J[Jake]
        CSM -->|servitorID == mortal.id| M[Mortal]
    end

    subgraph "Dead? Path (Old Coordinator)"
        TC[TavernCoordinator] --> CVM[ChatViewModel]
        TC --> J2[Jake]
        TC --> MS[MortalSpawner]
        CVM -->|send/sendStreaming| J2
        CVM -->|send/sendStreaming| M2[Mortal]
    end

    subgraph "Unused Consolidation"
        CS[ClodSession]
        CS -.->|"TODO: wire to Jake/Mortal"| J
        CS -.->|"TODO: wire to Jake/Mortal"| M
    end

    style CS fill:#ff9,stroke:#aa0
    style TC fill:#ddd,stroke:#999
    style CVM fill:#ddd,stroke:#999
    style J2 fill:#ddd,stroke:#999
    style M2 fill:#ddd,stroke:#999
```


### The Session Lifecycle (What Actually Happens)

```mermaid
sequenceDiagram
    participant U as User
    participant CT as ChatTile
    participant CSM as ClodSessionManager
    participant J as Jake/Mortal
    participant SS as SessionStore
    participant CNS as ClaudeNativeStorage
    participant SDK as ClodKit SDK

    Note over CT,CNS: App Launch
    CT->>CSM: loadHistory(servitorID)
    CSM->>SS: loadJakeSession(projectPath)
    SS-->>CSM: sessionId (from UserDefaults)
    CSM->>CNS: getMessages(sessionId, projectPath)
    CNS-->>CSM: messages from JSONL file
    CSM-->>CT: [ChatMessage] displayed in UI
    Note over CT: User sees full chat history

    Note over CT,SDK: User Sends Message
    U->>CT: "Hey Jake, continue where we left off"
    CT->>CSM: sendStreaming(servitorID, message)
    CSM->>J: sendStreaming(message)

    Note over J: Builds QueryOptions
    Note over J: SKIPS options.resume (commented out)

    J->>SDK: messenger.queryStreaming(prompt, options)
    Note over SDK: Brand new session created
    Note over SDK: Claude has NO context
    SDK-->>J: stream events + NEW sessionId
    J->>SS: saveServitorSession(newSessionId)
    Note over SS: Overwrites old sessionId
    J-->>CT: stream events
    Note over CT: User sees response
    Note over CT: But Claude had no memory of history
```


### The Six-Way Duplication

```mermaid
graph LR
    subgraph "Jake.swift"
        JS["send() lines 150-205"]
        JSS["sendStreaming() lines 210-284"]
        JPM["clodKitPermissionMode() lines 287-296"]
        JRC["resetConversation() lines 299-305"]
    end

    subgraph "Mortal.swift"
        MS["send() lines 150-189"]
        MSS["sendStreaming() lines 194-267"]
        MPM["clodKitPermissionMode() lines 311-320"]
        MRC["resetConversation() lines 270-282"]
    end

    subgraph "ClodSession.swift (unwired)"
        CS["send() lines 79-89"]
        CSS["sendStreaming() lines 91-131"]
        CPM["mapPermissionMode() lines 183-191"]
        CRC["resetConversation() lines 133-144"]
    end

    JS ~~~ MS ~~~ CS
    JSS ~~~ MSS ~~~ CSS
    JPM ~~~ MPM ~~~ CPM
    JRC ~~~ MRC ~~~ CRC

    style CS fill:#ff9
    style CSS fill:#ff9
    style CPM fill:#ff9
    style CRC fill:#ff9
```


## What's Duplicated — Method by Method


### 1. buildOptions() / option construction — 3 copies

All three build `QueryOptions` identically:

**Jake.swift:163-176**

```swift
var options = QueryOptions()
options.systemPrompt = Self.systemPrompt
options.permissionMode = clodKitPermissionMode()
options.workingDirectory = projectURL
// Session resume disabled — stale sessions cause ControlProtocolError.timeout
// TODO: Re-enable with fallback logic (try resume, catch timeout, start fresh)

if let server = currentMcpServer {
    options.sdkMcpServers["tavern"] = server
}
```

**Mortal.swift:160-166**

```swift
var options = QueryOptions()
options.systemPrompt = systemPrompt
options.permissionMode = clodKitPermissionMode()
options.workingDirectory = projectURL
// Session resume disabled — stale sessions cause ControlProtocolError.timeout
// TODO: Re-enable with fallback logic (try resume, catch timeout, start fresh)
```

**ClodSession.swift:148-168**

```swift
var options = QueryOptions()
options.systemPrompt = config.systemPrompt
options.permissionMode = Self.mapPermissionMode(mode)
options.workingDirectory = config.workingDirectory
// Session resume disabled — stale sessions cause ControlProtocolError.timeout
// TODO: Re-enable with fallback logic (try resume, catch timeout, start fresh)

for (key, server) in mcpServers {
    options.sdkMcpServers[key] = server
}
```

Only real differences: Jake has MCP server injection, Mortal doesn't. ClodSession abstracts both via its config.


### 2. Session persistence after response — 6 copies (once per send method)

**Jake.send():187-190**

```swift
if let newSessionId = result.sessionId {
    queue.sync { _sessionId = newSessionId }
    SessionStore.saveJakeSession(newSessionId, projectPath: projectURL.path)
}
```

**Jake.sendStreaming():243-246**

```swift
if let sessionId = info.sessionId, let self {
    self.queue.sync { self._sessionId = sessionId }
    SessionStore.saveJakeSession(sessionId, projectPath: self.projectURL.path)
}
```

**Mortal.send():175-178**

```swift
if let newSessionId = result.sessionId {
    queue.sync { _sessionId = newSessionId }
    SessionStore.saveServitorSession(servitorId: id, sessionId: newSessionId)
}
```

**Mortal.sendStreaming():228-229**

```swift
self.queue.sync { self._sessionId = sessionId }
SessionStore.saveServitorSession(servitorId: self.id, sessionId: sessionId)
```

**ClodSession** — consolidated into one private method:

```swift
private func persistSession(_ sessionId: String) {
    queue.sync { _sessionId = sessionId }
    switch config.sessionKeyScheme {
    case .perProject(let path):  SessionStore.saveJakeSession(sessionId, projectPath: path)
    case .perServitor(let id):   SessionStore.saveServitorSession(servitorId: id, sessionId: sessionId)
    }
}
```


### 3. Permission mode mapping — 3 identical copies

**Jake.swift:287-296**, **Mortal.swift:311-320**, **ClodSession.swift:183-191** — all three:

```swift
switch mode {
case .normal: return .default
case .acceptEdits: return .acceptEdits
case .plan: return .plan
case .bypassPermissions: return .bypassPermissions
case .dontAsk: return .dontAsk
}
```


### 4. resetConversation() — 3 copies

**Jake.swift:299-305**

```swift
queue.sync { _sessionId = nil }
SessionStore.clearJakeSession(projectPath: projectURL.path)
```

**Mortal.swift:270-282**

```swift
queue.sync {
    _sessionId = nil
    if _state != .done { _state = .idle }
}
SessionStore.clearServitorSession(servitorId: id)
```

**ClodSession.swift:133-144** — same pattern with `SessionKeyScheme` switch.


### 5. Error wrapping on session failure — 2 copies (Jake only)

**Jake.send():196-198** and **Jake.sendStreaming():263-265** both do:

```swift
if let sessionId = currentSessionId {
    throw TavernError.sessionCorrupt(sessionId: sessionId, underlyingError: error)
}
```

Mortal does NOT wrap errors this way — it just rethrows. ClodSession does wrap them.


### 6. Streaming state management — different per type (not duplicated)

This is legitimately different per servitor type:

- **Jake**: manages `_isCogitating` flag
- **Mortal**: manages `_state` enum + completion signal detection + commitment verification
- **ClodSession**: has no state management (it's session-only)


## Summary: What's Shared vs. Unique

| Concern | Jake | Mortal | ClodSession | Duplicated? |
|---------|------|--------|-------------|-------------|
| Build QueryOptions | Yes | Yes | Yes | **Yes — 3x** |
| Set resume (disabled) | Yes | Yes | Yes | **Yes — 3x** |
| Persist session after response | Yes (x2) | Yes (x2) | Yes (x2) | **Yes — 6x** |
| Map permission mode | Yes | Yes | Yes | **Yes — 3x** |
| Reset conversation | Yes | Yes | Yes | **Yes — 3x** |
| Error wrapping (sessionCorrupt) | Yes | No | Yes | Partial (2x) |
| `_isCogitating` state | Yes | No | No | Unique to Jake |
| State machine (idle->working->done) | No | Yes | No | Unique to Mortal |
| Completion signal detection | No | Yes | No | Unique to Mortal |
| Commitment verification | No | Yes | No | Unique to Mortal |
| MCP server injection | Yes | No | Yes (via config) | Shared differently |

The clean split: **session mechanics** (build options, resume, persist, reset) are duplicated. **Servitor behavior** (state machines, completion, MCP) is unique per type and should stay that way.


## The Core Problem

Resume is disabled everywhere. The commented-out code appears in these locations:

| File | Line | Method |
|------|------|--------|
| Jake.swift | 168-170 | `send()` |
| Jake.swift | 224-226 | `sendStreaming()` |
| Mortal.swift | 164-166 | `send()` |
| Mortal.swift | 207-209 | `sendStreaming()` |
| ClodSession.swift | 158-162 | `buildOptions()` |

All say the same thing:

```swift
// Session resume disabled — stale sessions cause ControlProtocolError.timeout
// TODO: Re-enable with fallback logic (try resume, catch timeout, start fresh)
```


## Key File Locations

| File | Purpose |
|------|---------|
| `Sources/TavernCore/Servitors/Jake.swift` | Daemon servitor — session logic lines 150-305 |
| `Sources/TavernCore/Servitors/Mortal.swift` | Worker servitor — session logic lines 150-282 |
| `Sources/TavernCore/Sessions/ClodSession.swift` | Consolidated session type (unwired) |
| `Sources/TavernCore/Providers/ClodSessionManager.swift` | ServitorProvider impl — routes to Jake/Mortal |
| `Sources/TavernCore/Persistence/SessionStore.swift` | UserDefaults session ID storage |
| `Sources/TavernCore/Persistence/ClaudeNativeSessionStorage.swift` | JSONL history reader |
| `Sources/TavernCore/Persistence/ClaudeSessionModels.swift` | Data models for stored sessions |
| `Sources/TavernKit/StreamTypes.swift` | StreamEvent enum |
| `Sources/TavernKit/ServitorProvider.swift` | ServitorProvider protocol |
| `Sources/Tiles/ChatTile/ChatTile.swift` | Chat UI tile — consumes StreamEvents |
| `Sources/Tiles/TavernBoard/WindowBoard.swift` | Root board — orchestrates tiles |
| `Sources/Tiles/TavernBoard/Sockets/ChatSocketPool.swift` | Tile cache per servitor |
| `Sources/TavernCore/Coordination/TavernCoordinator.swift` | Old coordinator (may be dead code) |
| `Sources/TavernCore/Errors/TavernErrorMessages.swift` | Error-to-user-message mapping |
| `Sources/TavernCore/Testing/ServitorMessenger.swift` | SDK abstraction protocol |
| `Tests/TavernCoreTests/JakeTests.swift` | Jake tests (resume assertions commented out) |
| `Tests/TavernCoreTests/MortalTests.swift` | Mortal tests (resume assertions commented out) |
