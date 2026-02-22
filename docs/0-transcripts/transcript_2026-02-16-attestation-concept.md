# Transcript: Attestation Concept Design

**Date:** 2026-02-16
**Session:** `097ad2bf`
**Topic:** Defining semantic conformance analysis — the `/attest` command

---

## The Problem

[U] We have spec audit that traces the PRD through to the code all the way through, but it does so nominally, by finding comments in code that mark the PRD or SPEC section that relates. This doesn't account for whether that code actually meets the requirements properly. We need some process that will do this deeper analysis, and I need a word aside from audit to describe this.

[C] The current audit proves **traceability** (code claims to implement REQ-X) but not **conformance** (code actually satisfies REQ-X). The gap: a provenance marker says "this code relates to REQ-AGT-001" but nobody checks whether the code actually does what REQ-AGT-001 demands.

___

[S] *This distinction — traceability vs conformance — is the conceptual foundation. Traceability is structural (links exist), conformance is semantic (the linked code satisfies the requirement's properties).*

---

## Naming Decision

[C] Presented naming candidates. "Attest" captures the formal, evidence-based nature of the process — making a sworn statement backed by evidence.

[U] Chose **"attest"** from the candidates.

[C] Attest it is.

---

## Tooling Hierarchy

[C] Where `/attest` sits relative to existing pipeline tools:

| Tool | Scope | Depth | Question |
|------|-------|-------|----------|
| `/spec-status` | Broad | Shallow | What's the coverage landscape? |
| `/audit-spec` | Broad | Structural | Are the structural links correct? |
| `/trace` | Narrow | Structural | Show one requirement's full chain |
| `/attest` | Narrow | **Deep** | Does the code actually satisfy this requirement? |

Each tool increases in depth. `/attest` is the only one that reads the actual code and makes a semantic judgment about whether the requirement's **properties** are satisfied.

---

## Three-Phase Process Design

[C] The attestation process has three phases:

**Phase 1 — Mechanical Gathering** (deterministic, no judgment):
- Parse target (`REQ-AGT-001`, `REQ-AGT`, or module number `004`)
- Read the spec block: title, source, priority, properties, testable assertion
- Find code via provenance markers in `Tavern/Sources/**/*.swift`
- Find tests via `.tags()` and provenance markers in `Tavern/Tests/**/*.swift`
- Read the relevant source and test files

**Phase 2 — Semantic Analysis** (AI-driven, per requirement):
- For each **property**: read against gathered code → verdict of `satisfied` / `partial` / `unsatisfied` / `unexamined`, citing specific code evidence
- For each clause of the **testable assertion**: read against test code → verdict of `verified` / `partial` / `unverified`, citing which tests cover it

**Phase 3 — Verdict Synthesis** (weakest-link rollup):
- All properties satisfied + all assertions verified = **CONFORMANT**
- Mix = **PARTIAL**
- None satisfied = **NON-CONFORMANT**
- Deferred priority or no code exists = **NOT ASSESSED** (with reason)

___

[S] *The Phase 1 / Phase 2 / Phase 3 separation keeps the deterministic work (file discovery, marker parsing) cleanly separated from the AI judgment work. Phase 1 is nearly identical to what `/trace` already does — reuse opportunity.*

---

## Integration Choices

[C] Three design decisions on how attestation integrates:

1. **Output displays inline** in conversation (same pattern as `/audit-spec` and `/trace`) — no automatic file writes
2. **Reuses provenance scanning** from `/trace` (Phase 1 is essentially the same gather step)
3. **Three invocation modes**: single requirement (`REQ-AGT-001`), prefix (`REQ-AGT`), or module number (`004`)
