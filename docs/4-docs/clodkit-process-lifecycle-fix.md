# ClodKit Process Lifecycle Fix — Brain Dump

## The Problem

ClodKit spawns `claude` CLI as a subprocess via `ProcessTransport`. When the consumer abandons a query (Task cancelled, XCTest timeout, dropped reference), the subprocess is never terminated. Orphaned `claude` processes accumulate indefinitely.

### Why It Happens

Three layers of encapsulation, zero cleanup:

```
ClaudeQuery (final class)
  └── ClaudeSession (actor)
        └── ProcessTransport (final class, @unchecked Sendable)
              └── _process: Process?   ← holds the subprocess, never killed on dealloc
```

None of these types have `deinit`. The `Process` object (and its subprocess) leak when ARC deallocates them.

### The Ownership Chain

```
Clod.query()                         // QueryAPI.swift:52-59
  → creates ProcessTransport          // local, passed to session
  → creates ClaudeSession             // local, passed to query
  → returns ClaudeQuery               // caller owns this

Consumer iterates:
  for try await message in query { }  // stream from ProcessTransport stdout

When consumer stops (cancel, timeout, drop):
  ClaudeQuery deallocated by ARC      // no deinit
  ClaudeSession deallocated by ARC    // no deinit
  ProcessTransport deallocated by ARC // no deinit
  Process object deallocated          // Foundation Process has no auto-terminate
  Subprocess lives on as orphan       // PID leak
```

### Where It Hurts

**Integration tests (Grade 3):** Each timed-out test leaks a `claude` process. Run 49 tests with a few timeouts and you've got a pile of orphans.

**Claude-in-Claude:** When running tests from within Claude Code, inherited env vars (`CLAUDECODE=1`) cause the spawned `claude` to detect nesting → sandbox failure (exit 71) or interactive permission hangs. The test times out, but the subprocess is never killed.

**Production (less severe):** In the Tavern app, if a user switches away from a servitor mid-response, the query might be abandoned. The subprocess should die. Currently it doesn't.


## The Fix

Three `deinit` implementations, one per layer. Each uses the mechanism appropriate to its isolation context.

### 1. ProcessTransport.deinit — Synchronous Kill

```swift
// ProcessTransport.swift
deinit {
    if let process = _process, process.isRunning {
        process.terminate()  // SIGTERM
    }
}
```

**Why synchronous:** `ProcessTransport` is a plain class. `_process` is a private var with no isolation boundary. Direct access is safe in deinit. No async, no actors, no Tasks.

**Why SIGTERM not SIGKILL:** SIGTERM lets `claude` clean up (flush logs, close connections). If it doesn't exit, the OS reaps it when the parent process dies. For a more aggressive approach, `kill(process.processIdentifier, SIGKILL)` is also fine since we're tearing down anyway.

**Existing cleanup method:** `closeInternal()` does SIGTERM → wait 5s → SIGKILL. But it's async (uses `Task.sleep`), so it can't run in deinit. The deinit just needs to fire SIGTERM — the graceful wait isn't worth it during teardown.


### 2. ClaudeSession.deinit — Direct Transport Close

```swift
// ClaudeSession.swift (actor)
deinit {
    transport.close()
}
```

**Why this works:** Actor `deinit` is always nonisolated (Swift spec). `transport` is `private let` — nonisolated access to `let` properties on actors is allowed. `transport.close()` is internally thread-safe (dispatches to its own `Task { closeInternal() }`).

**No choice to make here:** This is the only correct approach. Actor deinit can't await, and there's no isolation boundary to cross for `let` properties.

**Redundancy with ProcessTransport.deinit:** Yes, both layers call close/terminate. That's intentional — defense in depth. `transport.close()` does graceful shutdown (SIGTERM + wait + SIGKILL). `ProcessTransport.deinit` does immediate SIGTERM. Whichever runs first wins; the other is a no-op (process already dead).


### 3. ClaudeQuery.deinit — Detached Task

```swift
// ClaudeQuery.swift (final class)
deinit {
    let session = self.session
    Task { await session.close() }
}
```

**Why detached Task:** `ClaudeQuery` is a plain class. `session` is a `ClaudeSession` actor. Calling `session.close()` requires `await` (actor isolation). `deinit` is synchronous — can't await. The detached Task schedules the close on the actor's executor.

**Why NOT nonisolated:** The alternative — marking `ClaudeSession.close()` as `nonisolated` — works today because `close()` only touches `transport` (a `let`). But it creates a maintenance hazard: if anyone later adds mutable state cleanup to `close()`, the `nonisolated` annotation silently allows a data race. The compiler can't catch it. The correctness burden shifts from compiler to code review — and agents can't reliably catch code review problems.

**The detached Task keeps actor isolation intact.** Future changes to `close()` are protected by the compiler regardless of what state they touch.

**Failure mode:** If the cooperative thread pool is dead (app shutting down), the Task never runs. This is moot because:
1. The OS reaps child processes when the parent exits
2. `ProcessTransport.deinit` fires independently and kills the subprocess
3. The scenario that actually matters — between-test cleanup — works perfectly because the thread pool is alive


## The Design Principle

**Compiler-first safety:** Always prefer designs where incorrect code fails at compile time, not at code review. When choosing between `nonisolated` (shifts correctness to review) and detached Task (preserves compiler-enforced isolation), choose the Task. The failure mode of a no-op Task during shutdown is far less dangerous than a silent data race introduced by a future maintainer who didn't know `close()` was nonisolated.


## Testing Strategy

### Unit Tests

1. **ProcessTransport deinit terminates subprocess** — spawn a long-running process, drop the transport reference, verify the process is no longer running.

2. **ClaudeSession deinit calls transport.close()** — use a mock transport, create a session, drop the session reference, verify close() was called.

3. **ClaudeQuery deinit triggers session close** — create a query, drop it, verify the session's close path executed (may need a small delay for the detached Task to run).

### Integration Tests

4. **No orphaned processes after abandoned query** — call `Clod.query()`, iterate a few messages, cancel the Task, wait briefly, verify no `claude` processes match `--input-format stream-json`.

5. **No orphaned processes after XCTest timeout** — create a query that will hang (e.g., permission prompt), let `executionTimeAllowance` fire, verify cleanup in tearDown.

### Regression Test

6. **Normal query lifecycle still works** — full query → iterate → stream ends → verify no crashes from double-close (deinit fires after natural completion, process already dead, should be idempotent).


## Tavern-Side Mitigations (Already Applied)

While ClodKit is being fixed, the Tavern test runner has two layers of protection:

1. **`test-grade3.do`** strips `CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` via `env -u` before running `swift test` — prevents sandbox nesting detection entirely.

2. **All direct `QueryOptions` in Grade 3 tests** set `permissionMode = .plan` — prevents interactive permission prompts that would cause hangs.

These mitigations prevent the *cause* of hangs. The ClodKit deinit fix prevents the *consequence* (orphaned processes) for any future hang scenario.


## Files to Modify in ClodKit

| File | Change |
|------|--------|
| `Sources/ClodKit/Transport/ProcessTransport.swift` | Add `deinit` with `process.terminate()` |
| `Sources/ClodKit/Session/ClaudeSession.swift` | Add `deinit` with `transport.close()` |
| `Sources/ClodKit/Query/ClaudeQuery.swift` | Add `deinit` with `Task { await session.close() }` |
| `Tests/...` | New tests for deinit behavior (6 tests described above) |


## Related Context

- ProcessTransport source: `Sources/ClodKit/Transport/ProcessTransport.swift`
- ClaudeSession source: `Sources/ClodKit/Session/ClaudeSession.swift`
- ClaudeQuery source: `Sources/ClodKit/Query/ClaudeQuery.swift`
- QueryAPI (creates the chain): `Sources/ClodKit/Query/QueryAPI.swift`
- Transport protocol: `Sources/ClodKit/Transport/Transport.swift`
- ClodKit repo: `https://github.com/loupgaroublond/ClodKit` (issues disabled)
