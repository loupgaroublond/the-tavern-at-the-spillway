# ADR-007: Provenance Tracking

**Status:** Accepted
**Date:** 2026-02-14
**Context:** Machine-readable traceability between specifications and implementations (REQ-FID-001 through REQ-FID-007)


## Decision

Provenance tracking uses `// MARK:` comments in code and Swift Testing `.tags()` in tests to create bidirectional traceability between requirements and their implementations.

### Code Provenance Format

```swift
// MARK: - Provenance: REQ-AGT-001, REQ-AGT-003
```

**Canonical regex:** `// MARK: - Provenance: (REQ-[A-Z]+-[0-9]{3})(, REQ-[A-Z]+-[0-9]{3})*`

**Placement rules:**
- File-level: after imports, before the first declaration
- Function-level: immediately before the function it annotates
- Multiple requirements: comma-separated on a single MARK line

**Why MARK:** Integrates with Xcode's source navigator jump bar. Developers can jump to provenance annotations via the minimap. No custom tooling needed for basic navigation.

### Test Provenance Format

```swift
// MARK: - Provenance: REQ-AGT-001

@Test(.tags(.reqAGT001))
func jakeRespondsToUserMessage() async throws {
    // ...
}
```

**Tag naming convention:** `REQ-AGT-001` → `.reqAGT001` (drop `REQ-`, camelCase prefix, keep number)

**Tag definitions:** Each test target has a `Tags.swift` file with tag extensions:

```swift
extension Tag {
    @Tag static var reqAGT001: Self
    @Tag static var reqAGT002: Self
    // ...
}
```

**Why tags:** Enables filtered test runs — `swift test --filter` by requirement ID to run all tests covering a specific requirement.

### Bidirectional Traceability

| Direction | Mechanism | Maintained by |
|-----------|-----------|---------------|
| Backward (code → spec) | `// MARK: - Provenance:` comments | Developer at write time |
| Forward (spec → code) | Grep-based tooling scans | Computed on demand |
| Spec → directory | Downstream References section in spec modules | Developer (low churn) |

**Key principle:** Forward references are never manually maintained in spec modules at the file level. Tooling computes them from MARK comments. Spec modules only maintain directory-level Downstream References as a guide.

### Status Derivation

Requirement status is computed, not manually set:

| Status | Condition |
|--------|-----------|
| `specified` | Requirement exists in a spec module |
| `implemented` | At least one source file has a MARK comment referencing it |
| `tested` | At least one test has a `.tags()` entry referencing it |
| `verified` | All tagged tests pass |

### Backfill Strategy

Incremental — add provenance when touching a file. No big-bang migration. Over time, coverage grows organically as files are modified.


## Alternatives Considered

### JSON metadata sidecar files
Store provenance in `.meta.json` files alongside source files. **Rejected:** drifts from code (violates Invariant #5 — doc store is source of truth), adds filesystem clutter, requires custom tooling to read.

### Custom Swift doc tags (`/// @req REQ-AGT-001`)
Embed requirement references in documentation comments. **Rejected:** DocC does not support custom tags and produces warnings for unknown directives. Non-standard syntax confuses developers.

### Filename conventions (`Jake+REQ-AGT-001.swift`)
Encode requirement IDs in filenames. **Rejected:** one-to-many mapping (a file implements many requirements) doesn't fit filename conventions. Creates absurdly long filenames.

### External traceability matrix
Maintain a separate spreadsheet or markdown table mapping requirements to files. **Rejected:** contradicts the doc-store-is-truth principle. Manual maintenance guarantees drift. The source code itself is the most reliable place to record what it implements.

### `#warning`/`#error` compiler directives
Use Swift compiler directives to flag unimplemented requirements. **Rejected:** breaks compilation, not appropriate for tracking — these are metadata annotations, not build errors.


## Consequences

- Every source file touching a specified requirement gets a MARK comment (small per-file overhead)
- Test targets need `Tags.swift` files with requirement tag definitions
- Tooling beads (`/spec-status`, `/trace`, `/audit-spec`) can now implement against a concrete data contract
- Completeness becomes a verifiable question: grep for all REQ-* IDs, compare against MARK comments
- The Honor System in CLAUDE.md enforces provenance on new code written by Claude


## References

- REQ-FID-001 through REQ-FID-007 (`docs/2-spec/018-spec-fidelity.md`)
- PRD §19.4 (Completeness and Correctness Standards)
- Invariant #3: Commitments must be verified independently
