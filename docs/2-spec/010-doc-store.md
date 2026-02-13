# 010 — Document Store Specification

**Status:** complete
**Last Updated:** 2026-02-10

## Upstream References
- PRD: §4.5 (The Document Store), §6.6 (Hygiene)
- Reader: §7 (Core Systems — Document Store, Session Storage Layers, Session Lifecycle)
- Transcripts: transcript_2026-01-19-1144.md (doc store concept), transcript_2026-01-22-0015.md (three storage layers), transcript_2026-02-01-sdk-migration-and-session-forensics.md (session lifecycle)

## Downstream References
- ADR: --
- Code: Tavern/Sources/TavernCore/DocStore/, Tavern/Sources/TavernCore/Persistence/
- Tests: Tavern/Tests/TavernCoreTests/

---

## 1. Overview
Document store as the memory backbone for agent communication and state persistence. The doc store IS the filesystem — a file is a document. Code implements rules on top (validation, structure, relationships). Covers the three storage layers, hygiene rules for data lifecycle, and the session lifecycle model.

## 2. Requirements

### REQ-DOC-001: Filesystem Identity
**Source:** PRD §4.5
**Priority:** must-have
**Status:** specified

**Properties:**
- The document store is the filesystem — there is no separate "doc store" abstraction
- A file is a document; one file per node
- The "doc store" is the rules layer: validation, structure, and relationships on top of the filesystem
- No separate database, key-value store, or custom storage engine exists for document storage

**Testable assertion:** All persistent state is represented as files on disk. No separate database, key-value store, or custom storage engine exists for document storage.

### REQ-DOC-002: Source of Truth
**Source:** PRD §4.5, Invariant REQ-INV-005
**Priority:** must-have
**Status:** specified

**Properties:**
- If it is not in a file, it does not exist
- Agents communicate primarily through shared state in files (blackboard pattern)
- No in-memory-only state that matters to correctness may exist without a file-backed representation
- Killing the process and restarting produces consistent state from disk alone

**Testable assertion:** After any state mutation, the corresponding file on disk reflects the new state. Killing the process and restarting produces consistent state from disk alone.

### REQ-DOC-003: Multi-Purpose Storage
**Source:** PRD §4.5
**Priority:** must-have
**Status:** specified

**Properties:**
- The document store serves five roles: document storage, messaging system, work queues, agent nodes (with commitments), workflow templates
- Document types are namespaced to avoid collision
- Each role operates through the same filesystem abstraction

**Testable assertion:** Each of these document types can be created, read, and updated through the doc store rules layer. Document types are namespaced to avoid collision.

### REQ-DOC-004: Three Storage Layers
**Source:** Reader §7 (Session Storage Layers)
**Priority:** must-have
**Status:** specified

**Properties:**
- Storage is partitioned by ownership and lifecycle into three layers:
  - Layer 1 (Claude SDK, `~/.claude/projects/`): conversation history, session JSONL. Managed by Claude CLI, 30-day retention
  - Layer 2 (`.tavern/` in project): shareable config, templates, agent definitions. Version-controllable, travels with repo
  - Layer 3 (UserDefaults/iCloud): personal state (session IDs, window positions, agent list). Machine-local, not shared
- SDK-managed storage is not mixed with app-managed storage
- User preferences are separate from project state

**Testable assertion:** Session IDs are stored in UserDefaults (layer 3). Session history is read from `~/.claude/projects/` (layer 1). Agent definitions and templates live in `.tavern/` (layer 2).

### REQ-DOC-005: Session Lifecycle
**Source:** Reader §5 (Session Lifecycle)
**Priority:** must-have
**Status:** specified

**Properties:**
- Session storage has two independent states: local (JSONL files for history display) and server (Anthropic's servers for session resume)
- A session can be "displayable but not resumable" if server-side state expires while local JSONL remains
- History display works from local files alone (no API call needed)
- Session resume requires both local file and valid server-side state
- Archives preserve local forensics but cannot resurrect server-side sessions

**Testable assertion:** History display works from local JSONL files alone. Session resume requires both local file and valid server-side state. A session with expired server state displays history but fails on resume with an informative error.

### REQ-DOC-006: Authoritative Display
**Source:** Reader §7 (Document Store)
**Priority:** should-have
**Status:** specified

**Properties:**
- The UI can show a "direct from store" indicator to signal data integrity
- Content displayed with this indicator is byte-identical to the file on disk
- No LLM processing occurs between storage and display for authoritative content

**Testable assertion:** Content displayed with the "direct from store" indicator is byte-identical to the file on disk. No LLM processing occurs between storage and display for authoritative content.

### REQ-DOC-007: Hygiene — Dead Agent Cleanup
**Source:** PRD §6.6
**Priority:** must-have
**Status:** specified

**Properties:**
- Daemon processes handle cleanup of: dead agents, old changesets, stale overlays, orphaned workflows/documents/resources
- No orphaned resources accumulate indefinitely
- Cleanup occurs within a configurable time window after resources become orphaned

**Testable assertion:** After an agent is reaped, its associated resources are cleaned up within a configurable time window. No orphaned resources accumulate indefinitely.

### REQ-DOC-008: Path Encoding
**Source:** CLAUDE.md (Session Persistence Model)
**Priority:** must-have
**Status:** specified

**Properties:**
- `SessionStore.encodePathForKey()` replaces `/` and `_` with `-`, matching Claude CLI's scheme
- Jake's sessions are keyed per-project (`com.tavern.jake.session.<encoded-path>`)
- Servitor sessions are keyed per-agent UUID
- Session keys are unique per project and stable across app restarts

**Testable assertion:** `encodePathForKey("/Users/yankee/Projects/foo_bar")` produces `"-Users-yankee-Projects-foo-bar"`. Session keys are unique per project and stable across app restarts.

## 3. Properties Summary

### Storage Layer Properties

| Layer | Location | Managed By | Lifecycle | Shared? |
|-------|----------|-----------|-----------|---------|
| 1 | `~/.claude/projects/` | Claude CLI | 30-day retention | No (machine-local) |
| 2 | `.tavern/` in project | Tavern app | Version-controlled | Yes (travels with repo) |
| 3 | UserDefaults/iCloud | macOS | App-managed | No (personal) |

### Session State Properties

| Property | Holds When | Violated When |
|----------|-----------|---------------|
| Display from local only | History renders without API call | History display requires network |
| Resume requires both states | Resume needs local file + server state | Resume succeeds with only one |
| Informative failure | Expired server state → clear error message | Expired server state → cryptic failure |
| Archive preservation | Archives preserve all local forensics | Archives lose data |

### Core Doc Store Properties

| Property | Holds When | Violated When |
|----------|-----------|---------------|
| Filesystem identity | All state is files on disk | State exists in a separate database |
| Source of truth | Kill + restart = consistent state | In-memory state lost on crash |
| No orphans | Dead agent resources cleaned up | Resources accumulate indefinitely |
| Layer isolation | SDK storage not mixed with app storage | Tavern writes to `~/.claude/projects/` |

## 4. Open Questions

- **Doc store file structure/namespacing:** PRD §14 lists this as TBD. One file per node is established, but the directory hierarchy and naming conventions are not specified.

- **Doc store durability model:** PRD §14 says this "evolves over time." What are the initial durability guarantees? fsync after every write? Periodic flush?

- **Message protocol specifics:** PRD §14 lists this as TBD. How are messages encoded as files? What metadata is required?

- **Conflict resolution:** When two agents write to the same file simultaneously, what happens? Last-write-wins? Merge? Error?

## 5. Coverage Gaps

- **File locking:** No specification for concurrent file access by multiple agents. The shared workspace pattern (ADR-001 Shape E) implies concurrent access but the PRD does not specify locking semantics.

- **Document versioning:** The PRD mentions changesets for code files but does not specify whether doc store documents themselves are versioned.

- **Storage quotas:** No specification for maximum storage consumption by the doc store or per-agent storage limits.
