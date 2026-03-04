# Transcript: Rich Streaming Implementation & SDK Feature Parity ADR

**Date:** 2026-03-01
**Session:** 19508581-790b-476e-875f-8bbd590cd2ea (two context windows, session continued)
**Topics:** Rich streaming pipeline implementation (Plan A), streaming mode discovery, ADR-010 SDK feature parity tracking
**Branch:** `feature/rich-streaming`

---

## The Implementation Mandate

[U] Implement the following plan: Claude Code Feature Gap — Deep Implementation Plans.

*[T] The user provided a detailed implementation plan covering Plans A through J. The critical discovery driving Plan A: the streaming pipeline has two modes. Default (`includePartialMessages: false`) gives cumulative snapshots — one message at the end of a turn. Partial messages (`includePartialMessages: true`) gives `stream_event` messages with `content_block_start`, `content_block_delta`, `content_block_stop` — true incremental streaming per content block. The Tavern must switch to partial messages for real-time thinking, tool use, and text display.*

*The build strategy: feature branch in both repos (Tavern on `feature/rich-streaming`, ClodKit on `feature/streaming-types` if needed). Package.swift temporarily points to local ClodKit path (`../../ClodKit`) during development, reverts to version pin before merge.*

[C] Created the `feature/rich-streaming` branch. Read all key files. Launched an agent to explore ClodKit's full API surface, discovering concrete details:
- `SDKMessage` has `type`, `rawJSON`, `content`, `toolUseResult`
- `JSONValue` has NO `doubleValue` accessor (must use `numberValue`)
- `QueryOptions` HAS `includePartialMessages: Bool?`
- `ModelUsage` has `costUSD` (capital D)
- `ClaudeQuery` has `setModel`, `interrupt`, `rewindFiles`, `supportedModels`

Implemented Plan A (Rich Streaming Pipeline) across 16 files:

**Foundation types (TavernKit):**
- `StreamTypes.swift` — widened `StreamEvent` from 5 cases to 12, added `ToolUseInfo`, `ToolResultInfo`, `ToolProgressInfo`, `CompletionInfo`, `RateLimitInfo`, widened `SessionUsage` with cache token counts and cost
- `ChatMessage.swift` — added `toolUseId: String?` for tool_use/tool_result correlation

**Streaming pipeline:**
- `ServitorMessenger.queryStreaming()` — full rewrite to use `includePartialMessages: true` with content block state machine (thinking, text, tool_use deltas, tool results, system events, rate limits, prompt suggestions)

**Servitor wrappers, ChatTile state machine, views, mocks, and tests** — all updated to handle the new event types.

511 core tests + 28 integration tests passing.

---

## Branch Confirmation

[U] This is all in a branch?

[C] Yes — everything is on `feature/rich-streaming`. Main is untouched. The two build config files (Package.swift and project.yml) are pointed at local ClodKit and need to be reverted before merging to main.

---

## ADR-010: SDK Feature Parity as a Living Document

[U] Add an ADR that is for "100% implementation of the Claude SDK features in app." The first part is general rules about constantly staying on top of the SDK. The second part describes the entire list of features in the app we have to meet the current SDK version's capabilities, and lined up with the API, so that if we have a row with API but no feature, we know there's a gap in the requirements for that version. We'll update this when we update SDK versions.

*[T] The user is establishing a maintenance discipline: every SDK version bump triggers a feature audit. The ADR serves as both decision record (why we track parity) and living matrix (what's implemented vs what's a gap). This is unusual for an ADR — most are one-time decisions. This one is a process commitment with an appendix that evolves over time.*

[C] Created ADR-010 at `docs/3-adr/ADR-010-sdk-feature-parity.md` with two parts:

**Part 1 — SDK Currency Rules (5 rules):**
1. Version bump = feature audit (atomic commit with matrix update)
2. Feature branch workflow for local ClodKit development
3. No silent gaps — every capability gets a status (Implemented / Gap / Deferred / N/A / Disabled / Removed)
4. Quarterly review of deferred items
5. Test coverage follows features (Grade 1+2 mocks, Grade 3 real SDK)

**Part 2 — Feature Matrix (12 sections, ~120 capabilities tracked):**
Query & session lifecycle, QueryOptions, streaming & message types, mid-stream query control, MCP server infrastructure, permission system, hook system (all 19 hook types), elicitation, sandbox & security, session info & history, completion & usage data, transport layer.

**Gap summary at time of creation:** 62 implemented, 16 gaps, 36 deferred, 12 N/A, 1 disabled. The 16 active gaps map to implementation plans (B, C, D, E, G, H, J) with priority rankings.

___

[S] **Two key design artifacts from this session:**

1. **Streaming mode discovery** — The Claude Code SDK has two fundamentally different streaming modes. The default (`includePartialMessages: false`) gives cumulative message snapshots, usable only for text diffing. The partial mode (`includePartialMessages: true`) gives incremental `content_block_start/delta/stop` events, enabling real-time thinking display, tool use tracking, and per-block rendering. The Tavern's entire streaming pipeline was rebuilt around the partial mode.

2. **ADR-010 as a living matrix** — Unlike typical ADRs that record a one-time decision, ADR-010 establishes an ongoing maintenance discipline: every ClodKit version bump triggers a feature audit against the matrix. Each SDK capability has a tracked status. This converts "are we using the full SDK?" from a question someone has to investigate into a table someone can glance at.
