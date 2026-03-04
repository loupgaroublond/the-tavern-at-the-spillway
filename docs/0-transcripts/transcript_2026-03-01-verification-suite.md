# Transcript: Unified Verification Suite Design (ADR-009)

**Date:** 2026-03-01
**Session:** f38c7112-6465-4f9f-adbf-eee1d645611e
**Topics:** Unified verification suite concept, ADR-009 design, dead code reframed as unwired components, agent motivation philosophy, arbitrary threshold removal, bd -n 0 principle

---

## The Vision: One Report, All Gaps

[U] We need a combined verification suite to run periodically on this entire project. For instance, we need to make sure all tests pass. There are no build warnings. Run a spec audit and attestation run. Get code coverage reports from testing, and report if we have met targets. Code quality assessments especially with respect to architecture. Code quality assessments with respect to code requirements such as all tests must have timeouts, all X must subclass Y (for example). Anything else I'm missing here?

The goal is to use the various bits we have already and produce a single combined report at any time that gives us a complete gap analysis of the project all at once.

*[T] The user's framing is important: this is not about any single check but about having a complete picture on demand. The existing tools are fragmented — you invoke 6+ commands and mentally stitch results together. The value proposition is single-command completeness.*

[C] Explored all existing tools: `redo test`, `/attest-report`, `/audit-spec`, `/spec-status`, `/beads-audit`. Proposed 10 report sections covering build health, test health, code coverage, spec conformance, pipeline traceability, provenance coverage, beads state, structural rules (8 checks), architecture validation, and informational reports. Clarified: single mode (no quick vs. full split), configurable coverage targets per module, all four extra checks included as informational.

[U] Copy the beads-audit slash command and incorporate the beads audit into the report as well. Maximize parallelism here for the report. The entire spec for the verification report must be an ADR as well, and must detail exactly what the quality report will examine.

*[T] Two design requirements: (1) the spec lives in a permanent ADR (not just comments in the slash command), and (2) the implementation maximizes parallel execution. The ADR makes the spec durable and queryable. The parallelism minimizes wall time since build, tests, attestation, and structural checks are all independent.*

[C] Created both files simultaneously:
- `docs/3-adr/ADR-009-verification-suite.md` — the authoritative spec with all 10 sections, every check, pass criteria, grep patterns, and the dependency layer model
- `.claude/commands/verify.md` — the slash command, launching 4 background streams (build, tests+coverage, beads audit, attestation swarm) while running 3 inline streams in parallel

[U] Run it!

___

[S] *The "single combined report" framing is the key design principle behind ADR-009. The project already had strong but fragmented verification tools. The verification suite's value is not adding new checks — it's combining existing ones so that a complete gap analysis requires one command instead of six. The report's purpose is to surface what's broken and what's incomplete in a single glance.*

---

## The bd -n 0 Principle

*[During the first report run, the beads section showed fewer issues than expected.]*

[U] Update everywhere you can, make it very clear that when you run beads list, you must use `-n 0` to get all beads. This is mandatory, especially in the instructions for beads audit and this verification. Then rerun the beads audit portion and fix the report.

*[T] The user caught a silent truncation bug. Without `-n 0`, `bd list` returns a default paged result — agents reading the output would conclude the project has fewer open beads than it does. This is the kind of silent incompleteness that makes verification reports meaningless. The principle needs to be stated explicitly everywhere the command is used.*

[C] Updated ADR-009, verify.md, the beads-audit command, and CLAUDE.md to explicitly mark `bd list -n 0` as mandatory in every instance. The ADR now reads: "`-n 0` is mandatory — without it, bd returns a truncated default page."

___

[S] *The bd `-n 0` principle is a recurring pattern: tools with default pagination silently omit results, and any automated process that doesn't explicitly disable pagination will produce incomplete reports. When using bd in any automated context — verification, audit, analysis — always pass `-n 0` to get the complete set.*

---

## Dead Code Reframed as Unwired Components

[U] Let's reframe the dead code thing. Let's discuss dead code in terms of something is not wired up correctly, hence the code is dead, not live. We need to understand why: if it's a gap in the development of something, or if it's old code that can be removed. But dead, on its own, just means not wired, essentially.

*[T] This is a conceptual correction that changes how the analysis is interpreted. "Dead code" implies "delete it" — the standard response to dead code in production systems. But in an agent-driven development context, an entirely different failure mode is common: an agent implements a feature (writes the type, the methods, the tests) but doesn't complete the wiring. The session ends. The code compiles. Tests pass. But the feature silently sits disconnected. The analysis should surface this, not flag it for deletion.*

[C] Renamed Section 10b from "Dead Code Heuristics" to "Unwired Code Analysis" across ADR-009, verify.md, and the report. The framing shift: every unwired declaration gets classified as one of:
- **Development gap** — feature built but not yet wired (most common, needs attention)
- **Obsolete** — genuinely unreachable and safe to delete
- **Premature API** — provided for future consumers not yet built (no action needed)

[U] I believe all these dead components are actually features that need to be hooked up.

*[T] This confirms the hypothesis. In an early-stage project built largely by AI agents, the dominant failure mode is implementation without wiring — not obsolete code accumulation. Every "dead" component is a development gap, not technical debt to discard.*

[C] Recategorized all 19 findings in the report as development gaps. Updated the ADR to emphasize that the primary purpose of this analysis is catching incomplete implementation: code written but not connected.

___

[S] *The "dead code as unwired" reframing is a first-principles correction for agent-driven development. In human-written codebases, dead code accumulates from refactors and abandoned features. In agent-driven development, the dominant failure mode is different: agents implement features in isolation without completing the integration. The verification suite's unwired code analysis is a systematic backstop against this — every run surfaces components that exist but aren't connected, making the gap visible before it becomes invisible technical debt.*

---

## Agent Motivation Philosophy

[U] Let's add this explanation to the ADR, as well as remind the agent in the slash command that this step is a critical bulwark against common agent issues, and that the agent is doing its part to support the whole crew.

[U] The last sentence is "this is how you are doing your part to support your crew", to encourage the agent individually.

*[T] The user wants the agents executing this step to understand not just what to do but why it matters — and to feel the weight of that responsibility. The "crew" framing treats agents as teammates with accountability to each other, not just tool-callers. The specific phrasing "this is how you are doing your part to support your crew" is intentional — individual encouragement, collective accountability.*

[C] Added to verify.md, Section 10b:

> **Why this step matters — read this before executing:** This is one of the most important checks in the entire suite. In agent-driven development, a common failure mode is that an agent implements a feature — writes the type, the methods, the tests — but doesn't complete the wiring. The session ends, the code passes review because it compiles and tests pass, but the feature silently sits disconnected. By running this analysis exhaustively, you are catching what your fellow agents missed. You are the backstop. Do this thoroughly — every declaration checked, every unwired finding diagnosed. This is how you are doing your part to support your crew.

___

[S] *The crew motivation language is a deliberate design choice for multi-agent systems. Agents executing verification steps don't have context about what other agents did in previous sessions. By framing exhaustive analysis as "supporting your crew," the instruction creates a sense of accountability that translates to thoroughness. The agent isn't just running a check — it's functioning as a peer reviewer for every other agent that worked on this codebase.*

---

## Removing Arbitrary Thresholds

[U] No file to exceed 20 functions, where's that from?

[C] Section 10d (File Complexity) — written as an arbitrary threshold when defining the informational checks. Not from PRD, spec, or CLAUDE.md. Made it up.

[U] I think it's too arbitrary, I'd drop it.

*[T] The user is applying the "informational, not prescriptive" principle consistently. If a threshold wasn't derived from a real design decision, it shouldn't create false alarms. The report should surface data; decisions about what's acceptable are made by humans reviewing the data, not by invented cutoffs in the tool.*

[C] Dropped the 20-function limit from ADR-009, verify.md, and the report. Now the section just reports the data sorted descending — actual function counts per file without an invented threshold.

___

[S] *Thresholds in automated checks should derive from real design decisions, not arbitrary values invented during implementation. When a check would flag something as a "violation" based on a number someone made up, that check produces noise. The principle: if the threshold isn't in the PRD, spec, or CLAUDE.md, it belongs in neither the ADR nor the check. Report the data; let humans decide what's actionable.*

---

## Hierarchical Code Coverage

[U] Code coverage must be comprehensive. Break it down into a hierarchical table based on the file system, show the coverage per-file, and then the coverage per directory as you go up.

*[T] Flat coverage percentages obscure where the gaps are. A 30% overall figure tells you nothing about whether coverage is uniformly low or whether one well-tested module is carrying the average. A hierarchical tree format mirrors the actual file system — you can zoom in from "Sources/" to "TavernCore/" to "Chat/" to specific files, seeing the rollup at each level.*

[C] Updated ADR-009 Section 3 and verify.md to require a hierarchical filesystem tree format:

```
Sources/ (overall)
├── TavernCore/ (directory rollup)
│   ├── Chat/ (directory rollup)
│   │   ├── ChatViewModel.swift (per-file)
│   │   └── FileMentionAutocomplete.swift (per-file)
│   ...
├── TavernKit/ (directory rollup)
└── Tiles/ (directory rollup)
    ├── ChatTile/ (directory rollup)
    ...
```

Each node shows lines covered, total lines, and coverage percentage — with directories rolling up their children.

___

[S] *Hierarchical coverage reporting is a navigation tool. The flat "overall 30%" figure is a data point. The tree is a map. When coverage is low somewhere specific, the hierarchical view shows exactly where, guiding the next testing effort without manual investigation.*
