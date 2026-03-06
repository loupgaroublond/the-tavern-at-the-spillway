# ADR-011: Driver-Directory Pattern and Threading Philosophy

**Status:** Accepted
**Date:** 2026-03-05
**Context:** Consolidating scattered file-system access, eliminating `@unchecked Sendable` from persistence, and establishing threading guidelines


## Decision

### Driver-Directory Pattern

Per-project file-system access is consolidated into a single `ProjectDirectory` class, vended by `UnixDirectoryDriver`. The pattern:

1. **Driver** (`UnixDirectoryDriver`) — Factory that creates per-context Directory objects. Implements `ProjectProvider`.
2. **Directory** (`ProjectDirectory`) — Per-project file-system access. Implements `ProjectHandle`, `ResourceProvider`. Handles all servitor persistence (YAML frontmatter in `.tavern/servitors/`), session event logging (JSONL), file tree scanning, and file reading.

Previously, file-system access was scattered across 5+ classes (`ServitorStore`, `DocumentStore`, `DocStore`, `ServitorPersistence`, `DirectoryProjectHandle`). All have been consolidated into `ProjectDirectory`.


### Mechanism vs Policy

`ClodSession` is **mechanism** — it wraps ClodKit, holds ephemeral session state in memory, and returns session IDs to callers. It does not persist anything.

`ClodSessionManager` is **policy** — it decides when to persist session IDs, log session events, and manage servitor records. Persistence calls go through `ProjectDirectory`.

This separation means `ClodSession` needs no file I/O, no queues, and no store dependency.


### Threading Philosophy

Preference hierarchy for thread safety:

1. **Genuinely `Sendable`** (no mutable state) — `ProjectDirectory` has only `let` properties, a stateless `FileTreeScanner`, and thread-safe `FileManager.default`. No queues, no actors, no `@unchecked`.

2. **Actor isolation** — For types with mutable state that need cross-isolation access. Preferred over `DispatchQueue` for new code.

3. **`@MainActor`** — For UI-bound types (`@Observable` ViewModels, `SlashCommandDispatcher`).

4. **`@unchecked Sendable` is banned for new code.** Existing uses (19 remaining, tracked in jake-16g6) will be migrated incrementally. `@unchecked Sendable` shifts the correctness burden from the compiler to code review — the wrong tradeoff per the project's compiler-first safety principle.


### Protocol Isolation

TavernKit provider protocols (`ProjectProvider`, `ProjectHandle`, `ResourceProvider`, `ServitorProvider`, `CommandProvider`, `PermissionProvider`) are **not** `@MainActor`. Conforming types choose their own isolation strategy. Methods that access `@MainActor` state (e.g., `CommandRegistry` wrapping `@MainActor SlashCommandDispatcher`) are declared `async`.


## Consequences

- Single class (`ProjectDirectory`) for all per-project file-system access — easier to test, audit, and reason about
- `ClodSession` is simpler — no store, no queue, just in-memory session state
- `ServitorStore`, `DocumentStore`, `DocStore`, `ServitorPersistence`, `DirectoryProjectHandle`, `TavernCoordinator` deleted (dead code)
- New code must be genuinely `Sendable` or use actors — `@unchecked Sendable` requires justification and is tracked for removal
- Provider protocol methods may be `async` to bridge isolation boundaries
