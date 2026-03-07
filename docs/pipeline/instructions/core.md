# Core Instructions — All Agents

_Sources: 002-invariants, 003-system-architecture, 017-v1-scope, CLAUDE.md Honor System, ADR-007_

These instructions apply to every agent working on the Tavern codebase. Load this file plus the relevant domain supplement for your work item.

---

## 1. Non-Negotiable Invariants

These rules cannot be violated under any circumstances. Violations block completion.

1. **Test suite must pass before any feature ships.** No exceptions. If tests don't exist, write them first.

2. **Every feature must be testable.** If you can't test it automatically, redesign until you can.

3. **Commitments must be verified independently.** Agent says "done" means nothing. Deterministic assertion verifies.

4. **User attention is sacred.** Never force new content on user without consent. Surface questions, don't interrupt.

5. **Doc store is source of truth.** If it's not in a file, it doesn't exist. No in-memory-only state that matters.

6. **Agents cannot modify their own invariants.** The rules layer is outside agent control.

7. **Failures must be visible.** Silent failures are bugs. If something breaks, it must surface.

8. **Original project files are protected.** Until changeset is explicitly applied, original files are untouched.

---

## 2. Layer Model

```
UI Layer (thin, dumb)           <- layout + gestures + bindings only
ViewModel Layer                 <- all UX logic (@MainActor)
Application Layer               <- ClodSessionManager, MortalSpawner
Servitor Layer                  <- Jake, Mortal
Domain Layer                    <- Commitment, Assignment
Infrastructure Layer            <- ProjectDirectory, SessionStore, SDK
```

Each layer depends only on layers below it. Never reach up. No import of a higher layer from a lower one.

**Module structure:**
- `Tavern/Sources/Tavern/` — App target (SwiftUI entry point, Views)
- `Tavern/Sources/Tiles/` — Tile modules (one tile per SPM module)
- `Tavern/Sources/TavernCore/` — Framework target (all business logic)

---

## 3. Concurrency

- **`@MainActor`** on all ViewModels and UI-bound types.
- **Never block the cooperative thread pool:** No `Thread.sleep`, no `DispatchSemaphore.wait`, no sync file I/O. `await` suspends without blocking.
- **Global semaphore** for concurrent Anthropic calls (max ~10).
- **Sendable hierarchy** (ADR-011 preference order):
  1. Genuinely `Sendable` — no mutable state, no queues. `ProjectDirectory` is the exemplar.
  2. Actor isolation — for types with mutable state needing cross-isolation access.
  3. `@MainActor` — for UI-bound types.
- **`@unchecked Sendable` is banned for new code.** If a type needs to be `Sendable`, make it genuinely `Sendable`, use an `actor`, or restructure so it doesn't cross isolation domains.
- **Compiler-first safety:** Prefer designs where incorrect code fails at compile time, not at code review.

---

## 4. Observable

- **`@Observable` macro only.** All observable types use `@Observable`.
- **Banned:** `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`.
- **View side:** Use `@State`, `@Bindable`, and `@Environment(Type.self)`.

---

## 5. Tile Architecture

- Tiles are `@Observable` objects that own all their state and logic.
- Views are pure renderers: layout, styling, gestures, bindings. Nothing else.
- Views must NEVER trigger state initialization, data loading, or lifecycle management on tiles.
- Tiles initialize their own state at creation time in the socket/pool, not in response to SwiftUI view lifecycle events (`.task`, `.onAppear`).
- **One tile per SPM module.** Two tile types in one module means split into separate targets.

---

## 6. Code Standards

### Provenance (ADR-007)

New code implementing a specified requirement includes:
```swift
// MARK: - Provenance: REQ-PREFIX-NNN
```

New tests for specified requirements include `.tags()` with requirement-derived tags:
```swift
@Test(.tags(.reqAGT001))
```

Tag naming: `.req` + prefix letters (lowercase) + number, no hyphens. Example: `REQ-AGT-001` -> `.reqAGT001`.

### Logging

- Every view/service gets a static `Logger(subsystem: "com.tavern.spillway", category: "...")`.
- New code in TavernCore includes logging via `TavernLogger`.
- Debug builds must be instrumented thoroughly enough that issues can be diagnosed from logs alone.
- Five things to log in SwiftUI views: body evaluation, conditional branches, lifecycle events, task execution, state changes.

### Previews

Every SwiftUI view file must include at least one `#Preview` block (ADR-006).

### Errors

- Informative Error Principle: errors must be specific and actionable.
- Sum Type Error Design: enumerate all failure modes upfront via `TavernError` enum.
- Every error must surface. Silent failures are bugs.
- `TavernErrorMessages` maps errors to user-facing messages.

### General

- New servitor types accept `ServitorMessenger` for testability (ADR-003).
- No `AsyncStream` over Combine for new code — use language-level concurrency.
- Use `.task(id:)` when the task depends on a value that may change. Plain `.task` can run on stale view instances.

---

## 7. Testing Standards

### Grade System (ADR-002)

| Grade | What | When | Target |
|-------|------|------|--------|
| 1 | Property/unit, no mocks | Every change | `TavernCoreTests` |
| 2 | Unit with mocks | Every change | `TavernCoreTests`, `TavernTests` |
| 3 | Integration, real Claude | Once per unit of work | `TavernIntegrationTests` |
| 4 | XCUITest (steals focus) | Ask user first | `TavernUITests` |
| 5 | Stress/product testing | Pre-release | `TavernStressTests` |

Grade 3 tests are the canonical source of truth. Grade 2 mocks mirror their assertions.
Grade 4 **requires explicit user approval** — steals keyboard/mouse focus.

### Testing Principles

1. **Parallel Code Path Testing** — When code has multiple paths to the same outcome, tests cover ALL paths.
2. **Feature Toggle Coverage** — When tests disable a feature, other tests exercise it enabled.
3. **User Journey Integration Tests** — Test end-to-end paths users actually take.
4. **Symmetry Assertions** — When multiple APIs should behave consistently, assert symmetry.
5. **New Entity = New Test Coverage** — New entity types need equivalent coverage to existing types.

### Build & Test Commands

```bash
redo Tavern/build        # Build only
redo Tavern/test         # Grade 1+2 (safe for autonomous)
redo Tavern/test-core    # TavernCoreTests only (fast loop)
redo Tavern/test-grade3  # Integration (real Claude)
```

---

## 8. V1 Scope

### Ships in V1

- Jake daemon + mortal servitors with session persistence
- Two-mode spawning (user-spawn + Jake-spawn via MCP tools)
- Session history from Claude's native storage
- Multi-project with per-project isolation
- Multi-window architecture
- Resource panel (file tree + read-only viewer)
- Commitment verification (deterministic assertions)
- Doc store as blackboard

### Deferred (Not V1)

- Drones, monitor daemons
- Sandbox/changeset system
- Streaming responses
- Full workflow engine
- Gang of experts
- Plugin system
- iCloud sync

When implementing, check that your work aligns with V1 scope. If you're building something deferred, flag it.

---

## 9. Dependencies

| Package | Version | Purpose | Ships? |
|---------|---------|---------|--------|
| ClodKit | v0.2.63-r0 | Claude SDK wrapper | Yes |
| ViewInspector | v0.10.0+ | View-ViewModel wiring tests | No (test-only) |

No sandbox entitlement. Build output goes to `~/.local/builds/tavern`.

---

## 10. Self-Review Checklist

Before reporting completion:
- [ ] `redo Tavern/test` passes
- [ ] Every acceptance criterion: addressed
- [ ] Every code standard above: followed
- [ ] Every claimed requirement: has `// MARK: - Provenance:` marker
- [ ] Every test for a requirement: has `.tags()` annotation
- [ ] No `@unchecked Sendable` introduced
- [ ] No blocking calls introduced
- [ ] No silent error paths
- [ ] Logging added for new code paths
- [ ] `#Preview` blocks for new views
