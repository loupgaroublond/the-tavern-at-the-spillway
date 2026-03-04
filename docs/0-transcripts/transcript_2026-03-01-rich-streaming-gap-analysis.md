# Transcript: Rich Streaming Gap Analysis & Plan Development

**Date:** 2026-03-01
**Session:** 2ca63eb1-368a-4e39-b040-47f11c82a636
**Topics:** SDK gap analysis methodology, streaming pipeline discovery, plan depth requirements, build strategy for unpublished dependencies
**Related:** transcript_2026-03-01-rich-streaming-and-sdk-parity.md (implementation session that followed)

---

## The Gap Analysis Methodology

[U] Go peek at your neighbor ClodKit, for a preview of coming changes, based on the latest SDK version. Come up with a gap report on what Claude Code features we do not currently support in our chat windows. Be thorough. Put it in writing.

*[T] The user's approach: use the local development copy of ClodKit (at `../ClodKit`) as a window into upcoming SDK capabilities. Compare what ClodKit exposes against what the Tavern actually consumes. Any delta is a feature gap.*

[C] Launched parallel exploration agents — one for ClodKit's API surface, one for Tavern's consumption patterns. Discovered 17 gaps organized by what ClodKit provides vs what Tavern consumes, with file references and a priority table.

The critical finding: Gaps 1-4 are the same root problem. `ServitorMessenger.queryStreaming()` diffs `stringValue` between messages and only emits text deltas. Everything else — thinking blocks, tool inputs/outputs, system messages, cost data, rate limits — is thrown away at the parsing layer.

---

## The Unpublished SDK Problem

[U] How are you gonna do this if the SDK hasn't published yet?

[C] The gap report is based on what's in the local ClodKit at `../ClodKit` — the development copy. The Tavern's `Package.swift` pins ClodKit v1.0.0 (published), and `project.yml` points to the local path for dev. The report documents the delta between what the local ClodKit exposes and what Tavern consumes. Execution depends on ClodKit publishing first, or working against the local copy.

---

## Plan Depth Requirements

[U] I want you to break this down into very detailed plans based on the code you can read next door, but we won't execute just yet.

[C] Produced 10 detailed implementation plans (A through J) covering all 17 gaps, with exact type definitions (current → target), specific code for parsing `SDKMessage.rawJSON` content blocks, and the breaking changes in `StreamEvent`.

[U] ::squints:: We need to go deeper.

*[T] The user is pushing for implementation-ready depth, not design-document depth. The plans need to be specific enough that an agent can execute them without asking questions.*

[C] Acknowledged the plans were too shallow in critical areas — especially the content block diffing logic, the interleaving state machine, and the actual resume failure. Dug into the specific mechanics.

**Key discovery:** `includePartialMessages: true` unlocks real block-level streaming via `stream_event` messages with `content_block_start/delta/stop`. This changes everything about Plan A. The default mode only gives cumulative snapshots; partial messages give incremental events per content block.

Rewrote Plan A with:
- Full wire-format trace of `stream_event` messages for think → tool → text sequences (exact JSON)
- Complete `ServitorMessenger.queryStreaming()` rewrite using content block state tracking by index
- ChatTile state machine for interleaving multiple block types
- All message type routing

---

## Build Strategy: Working Against Unpublished APIs

[U] How are you going to test compilation?

*[T] The user catches a gap in the plan — everything assumes ClodKit types exist, but doesn't address how to verify compilation before ClodKit ships.*

[C] Can't compile against unpublished ClodKit APIs with version pins. Added build strategy:

- **Feature branch** `feature/rich-streaming` on Tavern
- **Local path dependency**: `Package.swift` line 18 and `project.yml` lines 24-26 switch from URL+version to local path (`../../ClodKit`)
- **Compile-test continuously**: `redo Tavern/build` catches type mismatches immediately against real ClodKit APIs
- **Revert before merge**: Switch back to version pin when ClodKit publishes and Tavern merges

___

[S] **Three process patterns established:**

1. **"Peek at your neighbor" gap analysis** — Use the local development copy of a dependency to preview upcoming capabilities and inventory gaps systematically. Compare what the dependency exposes vs what the consumer touches. The gap report becomes the backlog.

2. **Plan depth standard** — Implementation plans must be deep enough that an agent can execute without asking questions. Type definitions showing current → target, exact code for parsing logic, state machines with all transitions, wire-format JSON traces. "Detailed" means implementation-ready, not design-document-ready.

3. **Feature branch + local path dependency** — When developing against unpublished dependency APIs: feature branch in both repos, local path dependency for continuous compilation, revert to version pin before merge. Both `Package.swift` and `project.yml` need updating (and reverting).
