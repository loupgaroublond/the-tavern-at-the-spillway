# Infrastructure Instructions

_Sources: 010-doc-store, 011-sandbox, 012-workflows, ADR-011_

Load alongside `core.md` for work on the document store, sandbox/changeset system, workflows, or file system access.

---

## Document Store (REQ-DOC)

### Source of Truth (REQ-DOC-001, Invariant #5)
- If it's not in a file, it doesn't exist. No in-memory-only state that matters.
- The doc store is the shared workspace / blackboard.
- All agent communication goes through files.

### File-Based State (REQ-DOC-002)
- Agent state persisted in `.tavern/servitors/<name>/servitor.md` (YAML frontmatter).
- Session events in `.tavern/servitors/<name>/sessions.jsonl` (append-only).
- Commitments stored in doc store, attached to agent nodes.

### ProjectDirectory (REQ-DOC-003)
- Single type for all per-project file-system access.
- Genuinely `Sendable` (no mutable state, no queues) — the exemplar for thread safety.
- All file reads/writes go through `ProjectDirectory`.
- No direct file system access from other types.

### File Integrity (REQ-DOC-004)
- Content from doc store displayed to user is byte-identical to file on disk.
- No summarization or reinterpretation between storage and display.

### Hygiene (REQ-DOC-005)
- Dead agent cleanup is initially manual.
- Stale files, orphaned overlays tracked for eventual automated cleanup.

---

## Sandbox (REQ-SBX, Deferred for V1)

### Sandbox Primitives (REQ-SBX-001)
- Overlay filesystem per agent for isolation.
- Original project files protected until changeset is explicitly applied (Invariant #8).
- Each agent works in its own sandbox.

### Changeset System (REQ-SBX-002)
- Changes accumulated in overlay, not applied to original files.
- Changesets can be reviewed, approved, or rejected.
- Multiple changesets can coexist.

### Preflight Checks (REQ-SBX-003)
- Spawn-time verification before agents start.
- Ensures prerequisites are met.
- Blocks spawn if checks fail.

### Platform Sandboxes (REQ-SBX-004)
- Different sandbox types for different work: file sandbox, git sandbox, etc.
- Platform-specific isolation mechanisms.

Note: Sandbox is deferred for V1. Current implementation uses git worktrees for isolation.

---

## Workflows (REQ-WRK, Partially Deferred)

### Merge Queue (REQ-WRK-001)
- Coordinated changeset merging.
- Orchestrator manages merge ordering.
- Pipeline branch model (see process.md Section 5).

### Starter Templates (REQ-WRK-002, deferred)
- Pre-built workflow templates for common patterns.

### Workflow Engine (REQ-WRK-003, deferred)
- State machine templates for complex multi-step processes.

---

## Session Persistence

### Two-Level Storage
1. **Session IDs** — persisted in `.tavern/servitors/<name>/servitor.md` YAML frontmatter via `ProjectDirectory`. `ClodSession` holds in memory; `ClodSessionManager` persists after each response.

2. **Message History** — `ClaudeNativeSessionStorage` reads Claude CLI's native JSONL from `~/.claude/projects/`. Display-only.

3. **Session Events** — append-only JSONL in `.tavern/servitors/<name>/sessions.jsonl`. Tracks starts, expirations, breaks.

### Session Lifecycle
- Local JSONL enables history display.
- Server-side state enables resume.
- Sessions can be "displayable but not resumable" if server state expires.
- Resume-with-fallback: try `options.resume`, on timeout clear session, yield `.sessionBreak`, retry fresh.

---

## Thread Safety Patterns (ADR-011)

### For Infrastructure Types
1. **Genuinely `Sendable`** — preferred. `ProjectDirectory` has no mutable state.
2. **Actor isolation** — for types with mutable state needing cross-isolation access.
3. **`@MainActor`** — only for UI-bound types.

### Legacy Queue-Based Types (being migrated)
| Type | Queue | Protected State |
|------|-------|-----------------|
| Jake | `com.tavern.Jake` | `_sessionId`, `_isCogitating`, `_mcpServer` |
| Mortal | `com.tavern.Mortal` | `_state`, `_sessionId` |
| ServitorRegistry | `com.tavern.ServitorRegistry` | `_agents`, `_nameToId` |
| NameGenerator | `com.tavern.NameGenerator` | `_usedNames`, indices |
| CommitmentList | `com.tavern.CommitmentList` | `_commitments` |

### `@unchecked Sendable` Ban
Banned for new code. Use genuinely `Sendable`, `actor`, or restructure.

---

## Object Ownership

```
ProjectManager.shared (singleton)
    +-- openProjects: [TavernProject]
            +-- TavernProject
                    +-- ProjectDirectory (1)     <- all file-system access
                    +-- ClodSessionManager (1)   <- ServitorProvider
                    |       +-- Jake (1)
                    |       +-- MortalSpawner (1)
                    |               +-- ServitorRegistry (1)
                    |               +-- NameGenerator (1)
                    +-- CommandRegistry (1)
```

Each project gets its own stack. Only `ProjectManager` is a singleton.

---

## Key Files
| File | Purpose |
|------|---------|
| `ProjectDirectory.swift` | All per-project file-system access |
| `ClodSessionManager.swift` | ServitorProvider, session management + persistence |
| `ClodSession.swift` | ClodKit wrapper, mechanism layer |
| `SessionStore.swift` | History loading from Claude's native storage |
| `TavernProject.swift` | Single project representation |
| `ProjectManager.swift` | Multi-project management |
