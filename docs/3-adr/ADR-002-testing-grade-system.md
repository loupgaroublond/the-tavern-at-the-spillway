# ADR-002: Testing Grade System

**Status:** Accepted
**Date:** 2026-02-07
**Context:** Establishing a graded testing hierarchy so Claude can autonomously verify correctness without a human in the loop


## Decision

Tests are organized into 5 grades. Each grade subsumes all lower grades.

| Grade | What | When to Run | Interference |
|-------|------|-------------|--------------|
| **1** | Property/unit tests, no mocks | Every change | None |
| **2** | Unit tests with mocks | Every change | None |
| **3** | Integration with real Claude (headless, via `swift test`) | Once per unit of work | None (terminal only) |
| **4** | Tests requiring dedicated environment (XCUITest, VM) | When user isn't active | Steals focus |
| **5** | Stress/product testing | Pre-release | Resource-heavy |

**Runner commands:**

| Command | Grade | What It Runs |
|---------|-------|-------------|
| `redo Tavern/test` | 1+2 | `swift test --skip TavernIntegrationTests --skip TavernStressTests` |
| `redo Tavern/test-core` | 1+2 | `swift test --filter TavernCoreTests` |
| `redo Tavern/test-integration` | 1+2 | `swift test --filter TavernTests` |
| `redo Tavern/test-grade3` | 3 | `swift test --filter TavernIntegrationTests` |
| `redo Tavern/test-grade4` | 4 | `xcodebuild test -only-testing:TavernUITests` |
| `redo Tavern/test-all` | 1+2+3 | Runs `test` then `test-grade3` sequentially |


## Context

The Tavern is built by an AI agent (Claude) that needs to autonomously verify end-to-end correctness. Different test types have fundamentally different cost/interference profiles:

- **Grade 1+2** tests are fast, offline, and safe to run on every change. They catch regressions in logic and wiring.

- **Grade 3** tests call real Claude via the ClodeMonster SDK. They're slow (seconds to minutes per test) but are the source of truth for agent behavior. They run headless via `swift test` — no GUI, no focus stealing.

- **Grade 4** tests use XCUITest, which launches the app and simulates user interaction via accessibility APIs. This steals keyboard/mouse focus from the human. These run only when the user isn't actively working, or eventually in a Tart VM.

- **Grade 5** tests stress the system (many concurrent agents, large message histories). They're resource-heavy and run only before releases.


## Consequences

- Test targets map cleanly to grades: `TavernCoreTests` (1+2), `TavernTests` (1+2), `TavernIntegrationTests` (3), `TavernUITests` (4), `TavernStressTests` (5).

- `redo Tavern/test` is always safe for Claude to run autonomously — it skips integration and stress tests.

- Grade 3 tests are the canonical source of truth. Grade 2 mocks mirror their assertions but can never be more correct than the real thing.

- Verbose test output is saved to `~/.local/builds/tavern/test-reports/` for post-mortem debugging.
