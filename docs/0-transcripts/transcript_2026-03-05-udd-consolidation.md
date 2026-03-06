# UDD Consolidation — Driver-Directory Pattern & Threading Cleanup

**Date:** 2026-03-05 / 2026-03-06
**Sessions:** 1 (5 context continuations)
**Scope:** Consolidate file-system access into ProjectDirectory, strip @MainActor from protocols, simplify ClodSession, delete dead code, ban @unchecked Sendable
**Follows:** `transcript_2026-03-05-session-management-refactor.md` (UDD direction established)

---

## Planning Phase

*[T] The session began with a detailed 8-step plan ("crispy-noodling-charm") to execute the UDD consolidation discussed at the end of the session management refactor. The plan covered: stripping @MainActor from protocols, simplifying ClodSession, creating ProjectDirectory, wiring callers, updating tests, deleting dead code, auditing @unchecked Sendable, and documenting patterns.*

---

## @MainActor Removal from Protocols

*[T] All five TavernKit provider protocols (`ProjectProvider`, `ProjectHandle`, `ResourceProvider`, `ServitorProvider`, `CommandProvider`, `PermissionProvider`) had `@MainActor` removed. The key challenge was `CommandProvider` — its implementation (`CommandRegistry`) wraps `@MainActor SlashCommandDispatcher`, so the protocol methods became `async` to bridge the isolation boundary.*

___

[S] *Protocol isolation principle established: protocols should not impose isolation. Conforming types choose their own isolation strategy. Methods that bridge isolation boundaries use `async`.*

---

## ClodSession Simplified — Mechanism Only

*[T] ClodSession was stripped of its `ServitorStore` dependency and `DispatchQueue`. It now takes `initialSessionId: String?` in the constructor instead of reading from a store. Session IDs are returned to callers (in response tuples and stream events) rather than persisted internally. The `@unchecked Sendable` annotation remained due to Task captures of mutable state — tracked for future cleanup.*

___

[S] *The mechanism-vs-policy split is now fully realized: ClodSession holds ephemeral state in memory and returns it. ClodSessionManager (policy layer) decides when to persist session IDs and log events via ProjectDirectory.*

---

## ProjectDirectory — The Consolidation

*[T] A new `ProjectDirectory` class was created, genuinely `Sendable` (no mutable state). It merges logic from three deleted classes:*
- *`DirectoryProjectHandle` — id, rootURL, name, isReady*
- *`DocumentStore` — FileTreeScanner, binary extensions, maxFileSize, scan/read methods*
- *`ServitorStore` — YAML frontmatter, JSONL session events, servitor CRUD*

*The class implements `ProjectHandle`, `ResourceProvider`, and is plain `Sendable`. No queues, no `@unchecked`, no actors. All properties are `let`, FileTreeScanner is stateless, FileManager.default is thread-safe.*

---

## Threading Discussion

[U] I still have a lot of questions, why is ClodSession and ServitorStore both running dispatch queues at all?

[C] *ClodSession's queue protected `_sessionId` and `config`, but these are only mutated sequentially (one message at a time per servitor). The queue was unnecessary overhead.*

[U] Yeah, ClodSession exists to contain ClodKit, and a session is inherently an in-memory ephemeral thing.

[U] Actually, also, why is ProjectDirectory MainActor? We should really avoid using that as much as possible, and then consider actors if/when we do.

[C] *ProjectDirectory was never @MainActor — it's genuinely Sendable with no mutable state. The concern was well-placed though: the preference hierarchy is genuinely Sendable > actor > @MainActor, with @unchecked Sendable banned.*

[U] (on `@unchecked Sendable`) I need more explanation, `@unchecked` is a code smell, so spell this situation out for me.

[C] *`@unchecked Sendable` tells the compiler "trust me, this is safe to send across isolation boundaries" — but the compiler can't verify it. If someone later adds mutable state without adding synchronization, the compiler won't catch it. This shifts the correctness burden from compiler to code review, violating the project's compiler-first safety principle.*

___

[S] *Threading preference hierarchy established and documented in ADR-011:*
1. *Genuinely `Sendable` (no mutable state) — `ProjectDirectory` exemplar*
2. *Actor isolation — for types needing cross-isolation mutable state access*
3. *`@MainActor` — for UI-bound types only*
4. *`@unchecked Sendable` — banned for new code, 19 legacy uses tracked (jake-16g6)*

---

## Driver-Directory Pattern Finalized

[U] Doesn't matter, if we don't implement all of these in a single class, we're gonna duplicate a lot of code, and that's exactly what we're not doing. The design pattern language *is* for Tavern. Document it *for* Tavern.

*[T] The final pattern: `UnixDirectoryDriver` (factory, implements `ProjectProvider`) vends `ProjectDirectory` instances (per-project, implements all provider protocols). One class, one implementation, no delegation. Documented as ADR-011.*

---

## Build Issue — Upstream ClodKit

*[T] During execution, SPM tests failed because the ClodKit checkout at tag `v0.2.63-r0` had a corrupt/sparse working copy missing the `Sources/` directory.*

[U] Use upstream clod.

[U] Clean the build, update all the refs, then try again.

*[T] Cleaned `.build`, re-resolved packages. The re-fetched checkout had Sources correctly. Previous checkout was corrupt. Build and all tests passed after cleaning.*

---

## Dead Code Deletion

*11 files deleted:*
- `DocumentStore.swift`, `ServitorStore.swift` — absorbed into ProjectDirectory
- `DocStore.swift`, `Document.swift`, `ServitorNode.swift`, `ServitorPersistence.swift` — dead code, no production callers
- `TavernCoordinator.swift` — dead code since tileboard architecture
- 4 associated test files

*`ServitorStoreError` moved to `ProjectDirectory.swift` before deletion.*

---

## Final State

- **Build succeeds**, all Grade 1+2 tests pass
- **ADR-011** created documenting Driver-Directory pattern and threading philosophy
- **CLAUDE.md** updated: project structure, threading model, key files, honor system (`@unchecked Sendable` ban)
- **Bead jake-16g6** tracks 19 remaining `@unchecked Sendable` uses for incremental cleanup
- **Bead jake-o9a1** (from prior session) tracks context recovery design
