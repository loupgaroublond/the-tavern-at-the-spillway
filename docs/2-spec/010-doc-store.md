# 010 — Document Store Specification

**Status:** complete
**Last Updated:** 2026-02-16

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
- Database rules layer content is stored in the file store itself — they are also database records
- The only fundamental type and access to the document store is the same file API you get for files
- Runtime may maintain a memory cache, indices, and provide more sophisticated APIs on top
- The store is the entirety of the Tavern at that directory
- This does not preclude using `~/.tavern/` or macOS-provided storage for system/user level things
- No separate database, key-value store, or custom storage engine exists for document storage

**Note:** A follow-on ADR is needed for data store layering: low-level file layer with ACID-compliant layers on top for messaging, queues, etc.

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
- Documents serve one of five or more roles: document storage, messaging system, work queues, agent nodes, workflow templates
- Filesystem trees aren't namespaced in that sense — any document could potentially serve any role
- Each role operates through the same filesystem abstraction

**Testable assertion:** Each of these document roles can be created, read, and updated through the doc store rules layer.

### ~~REQ-DOC-004: Three Storage Layers~~
~~**Source:** Reader §7 (Session Storage Layers)~~
~~**Priority:** must-have~~
**Status:** dropped — *not related to doc store; describes Claude Code implementation details*

~~**Properties:**~~
~~- Storage is partitioned by ownership and lifecycle into three layers:~~
  ~~- Layer 1 (Claude SDK, `~/.claude/projects/`): conversation history, session JSONL. Managed by Claude CLI, 30-day retention~~
  ~~- Layer 2 (`.tavern/` in project): shareable config, templates, agent definitions. Version-controllable, travels with repo~~
  ~~- Layer 3 (UserDefaults/iCloud): personal state (session IDs, window positions, agent list). Machine-local, not shared~~
~~- SDK-managed storage is not mixed with app-managed storage~~
~~- User preferences are separate from project state~~

~~**Testable assertion:** Session IDs are stored in UserDefaults (layer 3). Session history is read from `~/.claude/projects/` (layer 1). Agent definitions and templates live in `.tavern/` (layer 2).~~

### ~~REQ-DOC-005: Session Lifecycle~~
~~**Source:** Reader §5 (Session Lifecycle)~~
~~**Priority:** must-have~~
**Status:** dropped — *mostly describes how Claude Code works, not a Tavern requirement*

~~**Properties:**~~
~~- Session storage has two independent states: local (JSONL files for history display) and server (Anthropic's servers for session resume)~~
~~- A session can be "displayable but not resumable" if server-side state expires while local JSONL remains~~
~~- History display works from local files alone (no API call needed)~~
~~- Session resume requires both local file and valid server-side state~~
~~- Archives preserve local forensics but cannot resurrect server-side sessions~~

~~**Note:** The new concept of chat discussions vs sessions belongs in §022 Chat Discussions & Sessions.~~

~~**Testable assertion:** History display works from local JSONL files alone. Session resume requires both local file and valid server-side state. A session with expired server state displays history but fails on resume with an informative error.~~

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

### ~~REQ-DOC-008: Path Encoding~~
~~**Source:** CLAUDE.md (Session Persistence Model)~~
~~**Priority:** must-have~~
**Status:** dropped — *servitor name is canonical ID per project; path encoding is implementation detail*

~~**Properties:**~~
~~- `SessionStore.encodePathForKey()` replaces `/` and `_` with `-`, matching Claude CLI's scheme~~
~~- Jake's sessions are keyed per-project (`com.tavern.jake.session.<encoded-path>`)~~
~~- Servitor sessions are keyed per-agent UUID~~
~~- Session keys are unique per project and stable across app restarts~~

~~**Testable assertion:** `encodePathForKey("/Users/yankee/Projects/foo_bar")` produces `"-Users-yankee-Projects-foo-bar"`. Session keys are unique per project and stable across app restarts.~~

## 3. Properties Summary

### Storage Layer Properties

| Layer | Location | Managed By | Lifecycle | Shared? |
|-------|----------|-----------|-----------|---------|
| 1 | `~/.claude/projects/` | Claude CLI | 30-day retention | No (machine-local) |
| 2 | `.tavern/` in project | Tavern app | Version-controlled | Yes (travels with repo) |
| 3 | UserDefaults/iCloud | macOS | App-managed | No (personal) |
| — | `~/.tavern/` | Tavern app | System/user level | No (machine-local) |

### Core Doc Store Properties

| Property | Holds When | Violated When |
|----------|-----------|---------------|
| Filesystem identity | All state is files on disk | State exists in a separate database |
| Source of truth | Kill + restart = consistent state | In-memory state lost on crash |
| No orphans | Dead agent resources cleaned up | Resources accumulate indefinitely |
| Layer isolation | SDK storage not mixed with app storage | Tavern writes to `~/.claude/projects/` |
| Crash-time partial flush | In-memory state fully flushed or not flushed at all | In-memory state partially flushed to disk at crash time, violating source-of-truth invariant |

## 4. Open Questions

- **Doc store file structure/namespacing:** Resolved: Not a thing. Filesystem trees aren't namespaced.

- **Doc store durability model:** Resolved: (a) disk hardware capability, (b) filesystem capability, (c) any in-memory proxy has ACID-compliant properties when flushing to disk.

- **Message protocol specifics:** Resolved: ADR material. Messaging requirements need a separate spec section. See pinned items.

- **Conflict resolution:** Resolved: Merge queue handles conflicts. One invariant: there's always a merge queue.

## 5. Coverage Gaps

- **File locking:** Pinned for future design.

- **Document versioning:** Resolved: Does not exist beyond what the filesystem provides.

- **Storage quotas:** Resolved: Matter for the filesystem and the computer's administrator.
