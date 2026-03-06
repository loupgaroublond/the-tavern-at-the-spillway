# UDD Consolidation — Threading Analysis Diagrams

**Date:** 2026-03-05
**Context:** Understanding the isolation domain problem before designing ProjectDirectory


## Current Isolation Domains

Five separate objects touch the file system, each from different isolation domains.

```mermaid
graph TB
    subgraph MainActor["@MainActor (Main Thread)"]
        TP["TavernProject.initialize()"]
        CSM[ClodSessionManager]
        CVM[ChatViewModel]
        RPT[ResourcePanelTile]
    end

    subgraph ClodQ["DispatchQueue: com.tavern.ClodSession"]
        CS_persist["ClodSession.persistSession()"]
        CS_clear["ClodSession.clearSession()"]
        CS_log["ClodSession.logSessionExpired()"]
    end

    subgraph StoreQ["DispatchQueue: com.tavern.ServitorStore"]
        SS_save["ServitorStore.save()"]
        SS_load["ServitorStore.load()"]
        SS_list["ServitorStore.listAll()"]
        SS_event["ServitorStore.appendSessionEvent()"]
    end

    subgraph DocStoreQ["@MainActor (DocumentStore)"]
        DS_scan["DocumentStore.scanDirectory()"]
        DS_read["DocumentStore.readFile()"]
    end

    TP -->|"store.listAll()"| SS_list
    TP -->|"store.save()"| SS_save
    CSM -->|"store.load()"| SS_load
    CSM -->|"store.save()"| SS_save
    CSM -->|"store.remove()"| SS_save

    CS_persist -->|"store.save()"| SS_save
    CS_clear -->|"store.load() + save()"| SS_load
    CS_log -->|"store.appendSessionEvent()"| SS_event

    RPT -->|"scanDirectory()"| DS_scan
    RPT -->|"readFile()"| DS_read

    style MainActor fill:#e1f5fe
    style ClodQ fill:#fff3e0
    style StoreQ fill:#fce4ec
    style DocStoreQ fill:#e8f5e9
```


## The Cross-Domain Problem

ClodSession runs on a background DispatchQueue. It calls ServitorStore methods (which have their own queue). Meanwhile, @MainActor callers also hit ServitorStore. Two isolation domains accessing one object.

```mermaid
sequenceDiagram
    participant MA as @MainActor
    participant CSQ as ClodSession Queue
    participant SSQ as ServitorStore Queue

    Note over MA,SSQ: User sends message to Jake

    MA->>CSQ: jake.send("hello")
    Note over CSQ: ClodSession.send() runs here

    CSQ->>SSQ: store.load("jake")
    SSQ-->>CSQ: ServitorRecord (has sessionId)

    Note over CSQ: Calls messenger.query()<br/>Gets response + new sessionId

    CSQ->>SSQ: store.save(updated record)
    Note over SSQ: Writes servitor.md to disk

    CSQ-->>MA: Return response text

    Note over MA,SSQ: Meanwhile, user opens resource panel

    MA->>MA: DocumentStore.scanDirectory()
    Note over MA: Separate FileManager,<br/>separate object,<br/>no coordination
```


## Why @unchecked Sendable Is Needed Today

The root problem: two isolation domains need the same object.

```mermaid
graph LR
    subgraph Problem["The Problem"]
        A["ClodSession Queue<br/>(background)"] -->|"needs to call"| B["ServitorStore"]
        C["@MainActor<br/>(main thread)"] -->|"needs to call"| B
    end

    subgraph Solutions["Possible Solutions"]
        D["A: @unchecked Sendable<br/>+ DispatchQueue"]
        E["B: actor ProjectDirectory"]
        F["C: @MainActor ProjectDirectory<br/>+ rethink ClodSession"]
        G["D: In-memory state<br/>persist at lifecycle only"]
    end

    D -.-|"works but<br/>code smell"| Problem
    E -.-|"works but ClodSession<br/>can't await in queue.sync"| Problem
    F -.-|"works if ClodSession<br/>becomes actor too"| Problem
    G -.-|"sidesteps: only<br/>@MainActor touches disk"| Problem

    style D fill:#fff3e0
    style E fill:#e8f5e9
    style F fill:#e1f5fe
    style G fill:#f3e5f5
```


## Solution A: @unchecked Sendable + DispatchQueue (current pattern)

Same as today's ServitorStore. Works but compiler can't verify safety.

```mermaid
graph TB
    subgraph MainActor["@MainActor"]
        TP[TavernProject]
        CSM[ClodSessionManager]
        RPT[ResourcePanelTile]
    end

    subgraph ClodQ["ClodSession DispatchQueue"]
        CS[ClodSession methods]
    end

    subgraph PD["ProjectDirectory<br/>@unchecked Sendable<br/>DispatchQueue: com.tavern.ProjectDirectory"]
        PD_save["saveServitor()"]
        PD_load["loadServitor()"]
        PD_scan["scanDirectory()"]
        PD_read["readFile()"]
        PD_event["appendSessionEvent()"]
    end

    TP -->|"queue.sync"| PD_load
    CSM -->|"queue.sync"| PD_save
    RPT -->|"queue.sync"| PD_scan
    CS -->|"queue.sync"| PD_save
    CS -->|"queue.sync"| PD_event

    style MainActor fill:#e1f5fe
    style ClodQ fill:#fff3e0
    style PD fill:#fce4ec
```

**Pros:** Minimal refactor — just merge classes.
**Cons:** `@unchecked Sendable` shifts safety burden to code review. A future maintainer could add unprotected state.


## Solution B: Actor Chain (compiler-enforced safety)

Both ProjectDirectory and ClodSession become actors. All access is `await`-based.

```mermaid
graph TB
    subgraph MainActor["@MainActor"]
        TP[TavernProject]
        CSM[ClodSessionManager]
        RPT[ResourcePanelTile]
    end

    subgraph CSActor["actor ClodSession"]
        CS_send["send()"]
        CS_persist["persistSession()"]
        CS_clear["clearSession()"]
    end

    subgraph PDActor["actor ProjectDirectory"]
        PD_save["saveServitor()"]
        PD_load["loadServitor()"]
        PD_scan["scanDirectory()"]
        PD_read["readFile()"]
        PD_event["appendSessionEvent()"]
    end

    TP -->|"await"| PD_load
    CSM -->|"await"| PD_load
    RPT -->|"await"| PD_scan

    CS_send -->|"await"| PD_save
    CS_persist -->|"await"| PD_save
    CS_clear -->|"await"| PD_load

    style MainActor fill:#e1f5fe
    style CSActor fill:#e8f5e9
    style PDActor fill:#f3e5f5
```

**Pros:** No `@unchecked` anywhere. Compiler enforces all isolation.
**Cons:** Requires converting ClodSession from DispatchQueue to actor. ClodSession currently uses `queue.sync {}` — can't `await` inside that. Deeper refactor of Jake/Mortal threading model too (they also use DispatchQueues that call ClodSession).

**Cascade:** Jake has `DispatchQueue(label: "com.tavern.Jake")` protecting `_isCogitating` and calling `session.send()`. If ClodSession becomes an actor, Jake needs `await session.send()` — which requires Jake's queue.sync blocks to become async too. Same for Mortal.


## Solution C: @MainActor ProjectDirectory + Rethink ClodSession

Make ProjectDirectory `@MainActor`. Only @MainActor code touches disk. ClodSession holds session IDs in memory and delegates persistence to @MainActor callers.

```mermaid
graph TB
    subgraph MainActor["@MainActor"]
        TP[TavernProject]
        CSM[ClodSessionManager]
        RPT[ResourcePanelTile]
        PD["ProjectDirectory<br/>(all file I/O here)"]
    end

    subgraph ClodQ["ClodSession DispatchQueue"]
        CS["ClodSession<br/>_sessionId in memory<br/>no disk access"]
    end

    TP -->|direct call| PD
    CSM -->|direct call| PD
    RPT -->|direct call| PD

    CS -.->|"returns sessionId<br/>in response tuple"| CSM
    CSM -->|"persists sessionId"| PD

    style MainActor fill:#e1f5fe
    style ClodQ fill:#fff3e0
```

**How it works:**
1. ClodSession.send() returns `(response, sessionId, didFallback)` — already does this
2. The @MainActor caller (ClodSessionManager/ChatViewModel) receives the sessionId
3. The @MainActor caller writes it to ProjectDirectory
4. ClodSession never touches disk — it just holds _sessionId in memory

**Problem:** ClodSession currently loads its initial sessionId from disk in its `init`. If it can't read from ProjectDirectory (because it's @MainActor and init isn't async), how does it get the initial sessionId?

**Fix:** Pass the initial sessionId as a constructor parameter. The @MainActor caller reads from ProjectDirectory and passes it in.

```mermaid
sequenceDiagram
    participant MA as @MainActor<br/>TavernProject
    participant PD as @MainActor<br/>ProjectDirectory
    participant CS as ClodSession<br/>(background queue)
    participant SDK as Claude SDK

    Note over MA,SDK: App Launch

    MA->>PD: loadServitor("jake")
    PD-->>MA: ServitorRecord (sessionId: "abc-123")
    MA->>CS: init(config, initialSessionId: "abc-123")
    Note over CS: _sessionId = "abc-123"

    Note over MA,SDK: User sends message

    MA->>CS: send("hello")
    CS->>SDK: query(resume: "abc-123")
    SDK-->>CS: response + newSessionId: "def-456"
    Note over CS: _sessionId = "def-456" (in memory)
    CS-->>MA: (response, sessionId: "def-456", didFallback: false)

    MA->>PD: saveServitor(record with sessionId: "def-456")
    Note over PD: Writes to disk

    Note over MA,SDK: Stale session scenario

    MA->>CS: send("hello again")
    CS->>SDK: query(resume: "def-456")
    SDK-->>CS: ControlProtocolError.timeout
    Note over CS: _sessionId = nil (in memory)
    CS->>SDK: query(no resume)
    SDK-->>CS: response + newSessionId: "ghi-789"
    Note over CS: _sessionId = "ghi-789"
    CS-->>MA: (response, sessionId: "ghi-789", didFallback: true)

    MA->>PD: appendSessionEvent(expired, "def-456")
    MA->>PD: saveServitor(record with sessionId: "ghi-789")

    Note over MA,SDK: App Quit
    Note over MA: No special action needed —<br/>already persisted after each message
```

**Pros:** No `@unchecked`, no actors, no DispatchQueue conversion. ClodSession keeps its DispatchQueue for protecting _sessionId and _isCogitating. ProjectDirectory is plain @MainActor.
**Cons:** Persistence moves from ClodSession to its callers. Session event logging (appendSessionEvent) also moves up. More code in ClodSessionManager.


## Solution D: In-Memory with Lifecycle Persistence

Like Solution C but lazier — only persist at specific lifecycle points, not after every message.

```mermaid
sequenceDiagram
    participant MA as @MainActor<br/>ProjectDirectory
    participant CS as ClodSession<br/>(in-memory only)
    participant Disk as File System

    Note over MA,Disk: App Launch
    MA->>Disk: Read .tavern/servitors/
    Disk-->>MA: ServitorRecords
    MA->>CS: Create with sessionId from record

    Note over MA,Disk: User sends message
    CS->>CS: messenger.query()
    CS->>CS: _sessionId = newId (in memory)
    Note over CS: No disk write!

    Note over MA,Disk: User clears chat
    MA->>CS: resetConversation()
    CS->>CS: _sessionId = nil
    MA->>Disk: Write break event + updated record

    Note over MA,Disk: App Quit / Project Close
    MA->>CS: Read current sessionId
    MA->>Disk: Write all ServitorRecords
    MA->>Disk: Flush pending session events

    Note over CS: If app crashes:<br/>Session ID lost<br/>Next launch = fresh session<br/>(acceptable: resume is best-effort)
```

**Pros:** Fewest disk writes. Simplest threading. No `@unchecked`.
**Cons:** Crash loses session ID. No session event audit trail during normal operation (events only flushed at lifecycle boundaries).


## Comparison Matrix

```
                    | @unchecked | Actor chain | @MainActor+caller | In-memory
--------------------|------------|-------------|--------------------|-----------
@unchecked needed?  |    YES     |     NO      |        NO          |    NO
Refactor scope      |   Small    |    Large    |      Medium        |   Medium
ClodSession changes |   Rename   |  Rewrite    |   Remove disk I/O  | Remove disk I/O
Compiler-safe?      |    No      |    Yes      |       Yes          |    Yes
Crash-safe?         |    Yes     |    Yes      |       Yes          |    No*
Disk write freq     |  Per-msg   |  Per-msg    |     Per-msg        | Lifecycle

* Session ID lost on crash — next launch starts fresh session (resume is best-effort anyway)
```
