# Document-Centric Architecture: Complete Analysis

This treatise documents the full research, reasoning, and trade-offs behind the Document-Centric architecture proposal for the Tavern multi-agent orchestrator.


## Research Findings


### Current State of the Codebase

The existing implementation has a split personality regarding persistence:

**Session storage (UserDefaults-based):**
- `SessionStore` in `/Tavern/Sources/TavernCore/Persistence/SessionStore.swift`
- Stores session IDs only, not full state
- Uses UserDefaults with path-encoded keys
- Per-project sessions for Jake, per-agent sessions for mortals
- Full message history delegated to Claude CLI's native storage (`ClaudeNativeSessionStorage`)

**DocStore infrastructure (exists but underutilized):**
- `DocStore` class in `/Tavern/Sources/TavernCore/DocStore/DocStore.swift`
- `Document` struct with YAML frontmatter + markdown content
- `AgentNode` for serializing agent state to documents
- `AgentPersistence` for save/restore operations
- Currently not wired into main flow; agents are runtime-only

**Runtime state:**
- `Jake` holds `_sessionId`, `_projectPath`, `_isCogitating` in memory
- `MortalAgent` holds `_state`, `_sessionId` in memory
- `TavernCoordinator` holds `chatViewModels` dictionary in memory
- `AgentRegistry` holds all agents in memory
- Loss of process = loss of mortal agent state (Jake survives via session ID persistence)


### Key Files Examined

| File | Key Insights |
|------|--------------|
| `prd_2026-01-19.md` | Invariant #5: "Doc store is source of truth — If it's not in a file, it doesn't exist" |
| `architecture-v1.md` | DocStore described but listed as "What's Not Implemented Yet: Persistent agent recovery" |
| `DocStore.swift` | Full CRUD implementation, thread-safe via DispatchQueue |
| `Document.swift` | Markdown + YAML frontmatter, parsing/rendering implemented |
| `AgentNode.swift` | Serialization to/from Document, including commitments |
| `AgentPersistence.swift` | Save/restore MortalAgent via DocStore (exists, unused in main flow) |
| `SessionStore.swift` | Only stores session IDs, not agent state |
| `Jake.swift` | Restores session ID on init, but not full conversation history |
| `MortalAgent.swift` | Session ID persistence exists, but lost on app restart |
| `TavernCoordinator.swift` | Manages agent lifecycle purely in memory |


## Mapping to PRD Requirements


### Invariant #5: "Doc store is source of truth"

The PRD states:
> "Doc store is source of truth — If it's not in a file, it doesn't exist. No in-memory-only state that matters."

Current implementation **violates this invariant**. Mortal agents exist only in memory; dismissing the app loses them. The DocStore infrastructure exists but isn't the source of truth.

**Document-Centric architecture makes this literal:**
- Agent state files ARE the agents
- No runtime state that isn't derived from documents
- Crash and restart = read documents and rebuild


### Invariant #3: "Commitments must be verified independently"

Current implementation stores commitments in `CommitmentList` (memory). Document-Centric would store them in agent documents:

```markdown
---
id: uuid-here
state: verifying
createdAt: 2026-01-24T10:00:00Z
---

## Assignment

Implement the frobnitz handler.

## Commitments

- ⏳ **Tests pass**
  - Assertion: `swift test --filter FrobnitzTests`

- ✅ **No lint errors**
  - Assertion: `swiftlint lint Sources/`
```

Verification becomes: read document, run assertions, write results back.


### Invariant #7: "Failures must be visible"

Documents are inherently visible. Every state transition, every failure, written to disk. Tools like `git diff`, `grep`, `tail -f` become debugging tools.


### Section 4.5: "The Document Store"

PRD says:
> "The doc store IS the filesystem. A file is a document. One file per node."
> "Contains: Agent nodes (with commitments attached), Work queues, Specs and PRDs, Messages, Workflow templates, Code files, Everything else."

This directly supports Document-Centric. The PRD envisions documents holding agent state, not just project artifacts.


### Section 6.3: "Work Queues"

> "Live in document store. Parents create them. Agents attach at spawn or mid-task."

Work queues as documents fits naturally:

```
.tavern/queues/
├── jake-main.md
├── feature-auth.md
└── drone-pool.md
```

Each queue file contains items with status, priority, assignment. Agents poll by reading files.


## Trade-offs Considered


### Trade-off 1: Performance vs. Durability

**Concern:** Every state change requires file I/O. Chat messages at high frequency could create bottlenecks.

**Analysis:**
- File writes are ~1ms for small documents on SSD
- FSEvents coalesces rapid changes
- Modern macOS uses unified buffer cache; "file" reads are often memory reads
- For chat messages: can batch (write every N messages or every T seconds)

**Mitigation strategies:**
1. **Write-behind buffering** — Collect changes, flush periodically
2. **Message documents vs. embedded** — Store messages as separate files, or embed recent in agent doc
3. **Async writes** — Fire-and-forget for non-critical state
4. **Read cache** — In-memory projection updated on FSEvents

**Verdict:** Acceptable for v1 scale (dozens of agents, hundreds of messages). Becomes problematic at thousands of concurrent messages.


### Trade-off 2: Schema Evolution

**Concern:** Document format becomes API. Changes require migration.

**Analysis:**
- YAML frontmatter + markdown body is flexible
- Unknown keys can be preserved (forward compatibility)
- Version field in frontmatter enables migration logic

**Mitigation:**
```yaml
---
schema_version: 2
id: uuid
state: working
# v2 adds: priority, parent_id
priority: 1
parent_id: parent-uuid
---
```

Migration on read: if `schema_version < current`, transform and write back.


### Trade-off 3: Query Complexity

**Concern:** Finding "all agents in state X" requires scanning all files.

**Analysis:**
- With dozens of agents, directory scan is negligible
- For specific queries, maintain index files (also documents)

**Mitigation:**
- `_index.json` files per directory (auto-generated, rebuild on startup)
- Or: accept O(n) scans for n < 100 agents


### Trade-off 4: Message Storage

**Concern:** Chat history can grow large. One file per message? Embedded in agent doc?

**Options considered:**

| Approach | Pros | Cons |
|----------|------|------|
| Messages embedded in agent doc | Single file, atomic | File grows unbounded |
| One file per message | Granular, git-friendly | Many files, query overhead |
| Chunked files (100 messages each) | Balanced | Complex addressing |
| Separate message log (append-only) | Fast writes | Harder to query |

**Recommendation:** Hybrid approach:
- Recent messages (last 50) embedded in agent doc for quick access
- Full history in `messages/{agent-id}/` directory, one file per session segment
- Claude CLI already stores full history; we store just enough to restore UI


### Trade-off 5: Multi-Process Safety

**Concern:** Multiple processes reading/writing same documents.

**Analysis:**
- FSEvents provides change notifications
- Atomic writes (`atomically: true` in Swift) prevent corruption
- Last-write-wins is acceptable for most state
- For contended resources (work queues): file locking or optimistic concurrency

**Mitigation:**
- Use `NSFileCoordinator` for critical documents
- Or: single writer per document (owner process)


## Implementation Complexity


### Phase 1: Foundation (Low Complexity)

Make existing DocStore infrastructure the source of truth.

1. **On agent spawn:** Call `AgentPersistence.save(agent)` (already exists)
2. **On state change:** Update document
3. **On app launch:** Call `AgentPersistence.loadAll()`, reconstruct agents
4. **On agent dismiss:** Delete or archive document

Code changes:
- `TavernCoordinator.spawnAgent()` — Add persistence call
- `MortalAgent` state setters — Trigger document update
- `TavernCoordinator.init()` — Load persisted agents

Estimated effort: 2-3 days


### Phase 2: FSEvents Integration (Medium Complexity)

Add reactive updates from filesystem changes.

1. **DocWatcher class:** Monitor `.tavern/` directory tree
2. **Change events:** Emit typed events (agent modified, message added, etc.)
3. **Projector:** Update in-memory state from events
4. **UI binding:** SwiftUI observes projector output

Code changes:
- New `DocWatcher` class using `DispatchSource.makeFileSystemObjectSource()` or FSEvents
- New `StateProjector` class
- `TavernCoordinator` observes projector instead of managing state directly

Estimated effort: 1-2 weeks


### Phase 3: Message Handling (Medium Complexity)

Separate message persistence from agent documents.

1. **MessageStore:** Parallel to DocStore, specialized for messages
2. **Batching:** Collect messages, flush periodically
3. **History loading:** Read message files on demand
4. **Compaction:** Archive old messages to reduce working set

This replaces/extends current `ChatViewModel.messages` handling.

Estimated effort: 1-2 weeks


### Phase 4: Work Queues (Medium Complexity)

Implement queue documents per PRD section 6.3.

1. **Queue document format:** Items with status, priority, agent assignment
2. **Queue operations:** Claim, complete, timeout
3. **Agent attachment:** On spawn, write to queue doc

Estimated effort: 1 week


### Total Estimated Effort

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Foundation | 2-3 days | None |
| FSEvents | 1-2 weeks | Foundation |
| Messages | 1-2 weeks | Foundation |
| Work Queues | 1 week | Foundation |

Phases 2-4 can proceed in parallel after Foundation.


## Migration Path from Current State


### Step 1: Dual-Write (Safe Migration)

Keep current runtime behavior, but also write to DocStore.

```swift
// In TavernCoordinator.spawnAgent()
let agent = try spawner.spawn(assignment: assignment)

// NEW: Also persist
try agentPersistence.save(agent)
```

This is additive; if it fails, runtime still works.


### Step 2: Read on Startup

On app launch, check for persisted agents and restore them.

```swift
// In TavernCoordinator.init() or similar
let persistedAgents = try agentPersistence.loadAll()
for node in persistedAgents {
    let agent = try agentPersistence.restore(name: node.name, claude: claudeFactory())
    try registry.register(agent)
}
```


### Step 3: Remove Runtime-Only Paths

Once persistence is verified stable, remove code that assumes runtime-only state.

- Remove `// Lost on app restart` comments
- Update tests to verify persistence
- Add crash-recovery tests


### Step 4: Make Documents Primary

Flip the relationship: documents drive runtime, not vice versa.

- Agent state changes write to document first
- FSEvents propagate to runtime
- UI observes projections


## Open Questions


### 1. Document Location

Where does `.tavern/` live?

Options:
- **Project root** — Natural for git tracking, but visible to users
- **Hidden in project** (`.tavern/`) — Less visible, still version-controllable
- **User data directory** (`~/Library/Application Support/Tavern/projects/{hash}/`) — Invisible, not version-controlled
- **Configurable** — User chooses

Recommendation: Hidden in project (`.tavern/`) with option to relocate via config.


### 2. Message Ownership

Who "owns" message history?

Options:
- **Tavern owns it** — Full documents in `.tavern/messages/`
- **Claude CLI owns it** — We just store references, read via `ClaudeNativeSessionStorage`
- **Hybrid** — Claude CLI has authoritative history, we cache recent for UI

Current state is hybrid (session ID stored, history read from Claude CLI). Document-Centric could maintain this or take full ownership.

Recommendation: Maintain hybrid for v1. Claude CLI history is authoritative. We store enough to restore UI (last N messages, session references).


### 3. Document Format Standardization

Should documents follow a specific schema (JSON Schema, TypeSchema) or remain loose?

Recommendation: Start loose with conventions. Add schema validation if document corruption becomes an issue.


### 4. Concurrent Modification

What happens if two processes modify the same document?

Options:
- **Last write wins** — Simple, potential data loss
- **File locking** — Prevents concurrent modification
- **Merge on conflict** — Complex, requires diff/merge logic
- **Single writer per document** — Owner process has exclusive write

Recommendation: Last write wins for v1 with single-app use case. Add locking if multi-process coordination is needed.


### 5. Performance Threshold

At what scale does Document-Centric become problematic?

Estimated limits (to be validated):
- Agents: ~100 before directory scan latency is noticeable
- Messages per agent: ~1000 embedded, unlimited in separate files
- Concurrent writes: ~10/second before I/O becomes bottleneck

Recommendation: Instrument and measure. Set alerts at 50% of estimated limits.


## Conclusion

The Document-Centric architecture aligns strongly with the PRD's vision of the doc store as source of truth. The existing DocStore infrastructure provides a foundation; the main work is integrating it into the runtime flow and adding FSEvents-driven reactivity.

The architecture trades some performance for debuggability, durability, and alignment with the PRD's stated principles. For the Tavern's expected scale (dozens of agents, hundreds of messages, single user), this trade-off is favorable.

Key risks:
- Message volume at scale (mitigated by batching, hybrid storage)
- Schema evolution (mitigated by versioning, forward compatibility)
- Performance ceiling (mitigated by caching, lazy loading)

The migration path is incremental: start with dual-write, verify stability, then shift to documents-as-primary. This minimizes risk while proving out the architecture.


## Appendix: Document Format Examples


### Agent Document (`agents/aragorn.md`)

```markdown
---
schema_version: 1
id: 550e8400-e29b-41d4-a716-446655440000
state: working
priority: 1
parent_id: null
session_id: abc123
created_at: 2026-01-24T10:00:00Z
updated_at: 2026-01-24T10:15:00Z
---

# Aragorn

## Assignment

Implement user authentication flow with OAuth2 support.

## Commitments

- ⏳ **All tests pass**
  - Assertion: `swift test --filter AuthTests`

- ⏳ **No security warnings**
  - Assertion: `security-scanner check Sources/Auth/`

## Recent Messages

> **User** (10:05): Start with the token refresh logic.

> **Aragorn** (10:06): I'll implement token refresh first. Looking at the OAuth2 spec...

## Notes

Working on refresh token flow. Need to handle token expiration edge case.
```


### Work Queue Document (`queues/feature-auth.md`)

```markdown
---
schema_version: 1
id: queue-feature-auth
created_at: 2026-01-24T09:00:00Z
---

# Feature: Authentication

Work queue for the authentication feature epic.

## Items

### Item 1: Token Refresh
- **Status:** in_progress
- **Assigned:** aragorn
- **Priority:** 1
- **Created:** 2026-01-24T09:00:00Z

### Item 2: Session Management
- **Status:** pending
- **Assigned:** null
- **Priority:** 2
- **Created:** 2026-01-24T09:00:00Z

### Item 3: Logout Flow
- **Status:** pending
- **Assigned:** null
- **Priority:** 3
- **Created:** 2026-01-24T09:00:00Z
```


### Message Chunk Document (`messages/aragorn/2026-01-24T10-00.md`)

```markdown
---
schema_version: 1
agent_id: 550e8400-e29b-41d4-a716-446655440000
session_id: abc123
start_time: 2026-01-24T10:00:00Z
end_time: 2026-01-24T10:30:00Z
message_count: 12
---

## Messages

### 10:00:00 — User
Start with the token refresh logic.

### 10:00:15 — Agent
I'll implement token refresh first. Looking at the OAuth2 spec for the refresh_token grant type.

### 10:02:30 — Agent [Tool Use: Read]
Reading `Sources/Auth/OAuth2Client.swift`

### 10:02:31 — Tool Result
```swift
// OAuth2Client implementation...
```

[... continues ...]
```
