# Testing & Quality Instructions

_Sources: 015-observability, 016-quality, 017-v1-scope, 018-spec-fidelity, ADR-002 (Testing Grades), ADR-005 (XCUITest), ADR-009 (Verification Suite), ADR-010 (Observability)_

Load alongside `core.md` for work on test infrastructure, quality, verification, observability, or spec fidelity.

---

## Testing Grades (ADR-002)

| Grade | What | When | Target | Safe for Agent? |
|-------|------|------|--------|----------------|
| 1 | Property/unit, no mocks | Every change | `TavernCoreTests` | Yes |
| 2 | Unit with mocks | Every change | `TavernCoreTests`, `TavernTests` | Yes |
| 3 | Integration, real Claude | Once per unit of work | `TavernIntegrationTests` | Yes |
| 4 | XCUITest (steals focus) | Ask user first | `TavernUITests` | **No** |
| 5 | Stress/product testing | Pre-release | `TavernStressTests` | No |

**Grade 3 tests are the canonical source of truth.** Grade 2 mocks mirror their assertions but can never be more correct than the real thing.

**Grade 4 requires explicit user approval** — steals keyboard/mouse focus. Launch args: `--ui-testing`, `--project-path <sandbox>`.

### Test Commands
```bash
redo Tavern/test          # Grade 1+2 (always safe)
redo Tavern/test-core     # TavernCoreTests only (fast loop)
redo Tavern/test-integration  # TavernTests only (wiring + SDK)
redo Tavern/test-grade3   # Real Claude, headless
redo Tavern/test-all      # 1+2+3 sequential
```

---

## Testing Principles

### 1. Parallel Code Path Testing
When code has multiple paths to the same outcome, tests must cover ALL paths. Two initializers that both load history? Both need tests.

### 2. Feature Toggle Coverage
When tests disable a feature (`loadHistory: false`), there MUST be other tests that exercise it enabled. No test-only code paths.

### 3. User Journey Integration Tests
Test end-to-end paths users actually take:
- Spawn servitor -> send message -> restart app -> click servitor -> verify history

### 4. Symmetry Assertions
When multiple APIs should behave consistently, add explicit tests asserting symmetry.

### 5. New Entity = New Test Coverage
New entity types need equivalent test coverage to existing types. If `Jake` has 20 tests, a new servitor type needs comparable coverage.

---

## Observability (REQ-OBS, ADR-010)

### Logging Standards (REQ-OBS-001)
- `os.log` with subsystem `com.tavern.spillway`.
- Categories: `agents`, `chat`, `coordination`, `claude`, `window`.
- Every view/service: static `Logger(subsystem:category:)`.
- New code in TavernCore uses `TavernLogger`.

### What to Log
- State transitions (servitor states, mode changes).
- API calls (params and responses).
- Errors (always, with context).
- Performance-relevant events (timing of long operations).

### Instrumentation Principle
Debug builds must be instrumented thoroughly enough that issues can be diagnosed from logs alone — without screenshots, videos, or human reproduction.

### Five Things in SwiftUI Views
1. Body evaluation with relevant state
2. Conditional branches taken
3. Lifecycle events (`.onAppear`, `.onDisappear`)
4. Task execution (entry, guards, results, exit)
5. State changes (via `.onChange`)

### Violation Monitoring (REQ-OBS-002)
- Configurable per-agent rules and enforcement.
- Violations surface as errors (Invariant #7).

### Metrics (REQ-OBS-003, deferred)
- Token time, utilization, saturation, amplification.
- Per-agent budgets and spend tracking.

---

## Quality Standards (REQ-QA)

### Code Quality
- All new code includes logging.
- Every feature requires tests per Testing Principles.
- No silent failures.
- `TavernError` enum covers all known failure modes.
- `TavernErrorMessages` maps to user-facing messages.

### Performance (REQ-QA-004)
- UI updates never block main thread.
- Servitor state management never blocks.
- Global semaphore respected for API calls.

### Test Infrastructure
- `MockServitor` conforms to `Servitor` protocol.
- `ServitorMessenger` protocol abstracts SDK boundary.
- `MockMessenger` for test doubles.
- `TestFixtures` for shared test data.

---

## Spec Fidelity (REQ-FID)

### Traceability Chain
```
PRD requirement -> Spec module (REQ-*) -> Code (// MARK: Provenance) -> Tests (.tags())
```

Every link in the chain must exist. Missing links are gaps.

### Provenance Markers (ADR-007)
- Source files: `// MARK: - Provenance: REQ-PREFIX-NNN`
- Tests: `.tags(.reqPREFIXNNN)` — prefix lowercase, no hyphens
- Example: `REQ-AGT-001` -> `.reqAGT001`

### Coverage Tracking
- `/spec-status` — live dashboard of provenance coverage
- `/trace` — trace a single requirement through the chain
- `/audit-spec` — full PRD-to-spec gap analysis
- `/attest` — semantic conformance (does code satisfy spec properties?)

---

## Verification Suite (ADR-009)

The `/verify` command runs an 11-section report:

1. Build health (warnings)
2. Test health (pass/fail/coverage)
3. Coverage analysis
4. Conformance checking
5. Traceability audit
6. Provenance verification
7. Beads audit
8. Structural rules (test timeouts, previews, logger, MainActor, etc.)
9. Architecture review
10. Informational metrics
11. SDK feature parity

### Structural Rules Checklist
- [ ] Test timeouts on `@Suite` declarations
- [ ] `#Preview` blocks in View files
- [ ] Logger setup in TavernCore files
- [ ] Provenance markers in source files
- [ ] `@MainActor` on ViewModels
- [ ] `ServitorMessenger` DI in servitor types
- [ ] No `Thread.sleep` or `DispatchSemaphore.wait`
- [ ] No layer violations (import graph)
- [ ] No `@unchecked Sendable`

---

## XCUITest Patterns (ADR-005)

- E2E tests NEVER mock. Purpose is to validate actual user experience.
- If a response takes 30 seconds, the test waits 30 seconds.
- Launch arguments for test mode: `--ui-testing`, `--project-path <sandbox>`.
- Test reports go to `~/.local/builds/tavern/test-reports/`.

---

## V1 Quality Bar

### Must Ship
- All Grade 1+2 tests pass.
- All provenance chains complete for implemented requirements.
- No known invariant violations.
- Logging sufficient for post-mortem diagnosis.

### Deferred
- Full coverage metrics enforcement.
- Automated violation monitoring.
- Performance benchmarks.
- Stress testing suite.
