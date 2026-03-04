# ADR-010: SDK Feature Parity

**Status:** Accepted
**Date:** 2026-03-01
**Context:** The Tavern wraps ClodKit (which wraps the Claude Code CLI SDK) through a `ServitorMessenger` abstraction layer. As ClodKit evolves — adding new capabilities, changing APIs, deprecating features — the Tavern must stay current. Without a systematic tracking mechanism, feature gaps accumulate silently. This ADR establishes both the rules for staying current and a living feature matrix that makes gaps immediately visible.


## Part 1: SDK Currency Rules

### Rule 1: Version Bump = Feature Audit

Every time ClodKit's version pin changes in `Package.swift`, the developer must:

1. Read ClodKit's changelog / diff between old and new version
2. Update the feature matrix in Part 2 of this ADR
3. For each new SDK capability: add a row with status `Gap` or `Implemented`
4. For each removed SDK capability: flag it for discussion — never silently drop a feature row
5. For each changed SDK capability: verify Tavern's usage still compiles and behaves correctly

This audit happens on the same PR as the version bump. The version bump and matrix update are a single atomic commit.


### Rule 2: No Silent Gaps

Every SDK capability falls into exactly one category:

| Status | Meaning | ADR Violation? |
|--------|---------|----------------|
| **Implemented** | Tavern uses this capability in production code | No |
| **Gap** | SDK exposes it, Tavern does not support it | **Yes** — must be resolved |
| **Deferred** | Gap with a plan to implement — a violation given a stay of execution | **Yes** — tracked with timeline |
| **Broken** | Tavern has code for it but it doesn't work | **Yes** — must be fixed |
| **N/A** | SDK exposes it, but it doesn't apply to Tavern's architecture | No |
| **Deprecated** | SDK removed this capability — ask user how to handle before dropping | No |

Every `Gap`, `Deferred`, and `Broken` row is a violation of this ADR. Each must have a corresponding bead (issue) tracking resolution. Zero violations is the requirement — every SDK capability must be `Implemented`, `N/A`, or `Deprecated`.


### Rule 3: Verification

Every row in the feature matrix is verified in depth by `/verify` (ADR-009, Section 11: SDK Feature Parity). For each `Implemented` capability, verification confirms the implementation actually works — not just that code exists, but that the feature is wired end-to-end. For each violation (`Gap`, `Deferred`, `Broken`), verification confirms the violation still exists and reports it. This is an exhaustive, per-row check — no sampling, no shortcuts.


---


## Part 2: Feature Matrix (ClodKit v0.2.63-r0)

Last audited: 2026-03-03


### 2.1 Query & Session Lifecycle

| SDK Capability | Status | Notes |
|---|---|---|
| `Clod.query(prompt:options:)` — single prompt | Implemented | `LiveMessenger.query()` |
| `ClaudeQuery` async iteration | Implemented | `LiveMessenger.queryStreaming()` |
| `ClaudeQuery.interrupt()` | Implemented | Cancel button in ChatTile |
| `ClaudeQuery.sessionId` | Implemented | Session persistence in SessionStore |
| `options.persistSession` | Implemented | Default true, used implicitly |
| `options.resume` — session resume | Broken | Causes `ControlProtocolError.timeout` with stale sessions. ClodKit deinit fix prevents process leaks but doesn't solve server-side session expiry. Plan B: try resume, catch timeout, start fresh. |
| `Clod.query(prompt:options:)` — AsyncSequence prompt | Deferred | Multi-turn streaming input not needed yet |
| `Clod.query(options:promptStream:)` — closure prompt | Deferred | Alternative API shape, not needed |
| `ClaudeQuery.close()` | Deferred | Relying on scope-based cleanup |
| `options.continueConversation` | Deferred | Less precise than resume; risks wrong session with multiple servitors |
| `options.forkSession` | Deferred | No branching conversation use case yet |
| `options.sessionId` | Deferred | Could be useful for deterministic session naming |
| `options.resumeSessionAt` | Deferred | Message-level resume not needed yet |


### 2.2 QueryOptions — Core Configuration

| SDK Capability | Status | Notes |
|---|---|---|
| `systemPrompt` | Implemented | Jake character prompt, Mortal assignment prompt |
| `permissionMode` | Implemented | Maps to SessionModeStrip (plan/normal/acceptEdits/bypass/dontAsk) |
| `workingDirectory` | Implemented | Per-project directory in ClodSession |
| `environment` | Implemented | Sets `CLAUDECODE` to prevent nested detection |
| `canUseTool` callback | Implemented | Plan mode + ExitPlanMode interception in LiveMessenger |
| `includePartialMessages` | Implemented | Enabled in LiveMessenger for rich streaming |
| `promptSuggestions` | Implemented | Parsed in LiveMessenger, displayed as chips in ChatTileView |
| `model` | Gap | No model picker UI. Plan D. |
| `fallbackModel` | Gap | Depends on model picker (Plan D) |
| `maxThinkingTokens` | Gap | Depends on thinking config UI (Plan D) |
| `thinking` (ThinkingConfig) | Gap | No adaptive/enabled/disabled toggle. Plan D. |
| `effort` | Gap | No effort level picker. Plan D. |
| `maxBudgetUsd` | Gap | No budget cap UI |
| `appendSystemPrompt` | Deferred | Could be useful for per-conversation context injection |
| `maxTurns` | Deferred | No turn limit use case yet |
| `logger` | Deferred | Could route ClodKit logs to TavernLogger |
| `allowedTools` | Deferred | No per-servitor tool filtering yet |
| `blockedTools` | Deferred | No per-servitor tool blocking yet |
| `disallowedTools` | Deferred | No per-servitor tool blocking yet |
| `additionalDirectories` | Deferred | Servitors work in project directory only |
| `agent` | Deferred | Agent delegation handled at Tavern layer |
| `agents` (AgentDefinition) | Deferred | Tavern has its own servitor orchestration |
| `betas` | Deferred | No beta features needed currently |
| `outputFormat` (structured) | Deferred | No structured output use case yet |
| `stderrHandler` | Deferred | Could capture CLI stderr for diagnostics |
| `settingSources` | Deferred | No custom settings sources needed |
| `strictMcpConfig` | Deferred | Default MCP validation sufficient |
| `plugins` (SdkPluginConfig) | Deferred | No plugin use case yet |
| `tools` (ToolsConfig) | Deferred | No custom tool config needed |
| `cliPath` | N/A | Default CLI discovery works |
| `debug` | N/A | Development use only |
| `debugFile` | N/A | Development use only |
| `executableArgs` | N/A | Advanced CLI control not needed |
| `extraArgs` | N/A | Advanced CLI control not needed |
| `spawnClaudeCodeProcess` | N/A | Default process spawning works |


### 2.3 Streaming & Message Types

| SDK Capability | Status | Notes |
|---|---|---|
| `StdoutMessage.regular(SDKMessage)` | Implemented | Primary message processing path |
| `SDKMessage.type == "stream_event"` | Implemented | Content block parsing in LiveMessenger |
| `SDKMessage.type == "assistant"` | Implemented | Fallback path (cumulative messages) |
| `SDKMessage.type == "result"` | Implemented | CompletionInfo extraction |
| `SDKMessage.type == "system"` | Implemented | Status messages (e.g. "compacting") |
| `SDKMessage.type == "user"` (tool results) | Implemented | Tool result extraction |
| `SDKMessage.type == "tool_progress"` | Implemented | ToolProgressInfo in ChatTile |
| `SDKMessage.type == "prompt_suggestion"` | Implemented | Prompt suggestion chips |
| `SDKMessage.type == "rate_limit"` | Implemented | Rate limit banner + message |
| `content_block_start` (text) | Implemented | Text block detection |
| `content_block_start` (thinking) | Implemented | Thinking block detection |
| `content_block_start` (tool_use) | Implemented | Tool use block with name + ID |
| `content_block_delta` (text_delta) | Implemented | Real-time text streaming |
| `content_block_delta` (thinking_delta) | Implemented | Real-time thinking display |
| `content_block_delta` (input_json_delta) | Implemented | Tool input accumulation |
| `content_block_stop` | Implemented | Block finalization |
| `SDKAssistantMessageError` | Deferred | Could surface auth/billing/rate errors distinctly |
| `StdoutMessage.keepAlive` | Deferred | Not surfaced to UI |
| `StdoutMessage.controlRequest` | N/A | Handled internally by ClodKit |
| `StdoutMessage.controlResponse` | N/A | Handled internally by ClodKit |


### 2.4 Session Query Control (Mid-Stream)

| SDK Capability | Status | Notes |
|---|---|---|
| `ClaudeQuery.setModel()` | Gap | Plan D |
| `ClaudeQuery.setMaxThinkingTokens()` | Gap | Plan D |
| `ClaudeQuery.supportedModels()` | Gap | Plan D |
| `ClaudeQuery.rewindFiles(to:)` | Gap | Plan G — needs message UUID tracking |
| `ClaudeQuery.rewindFilesTyped(to:dryRun:)` | Gap | Plan G |
| `ClaudeQuery.mcpStatus()` | Gap | Plan H |
| `ClaudeQuery.reconnectMcpServer(name:)` | Gap | Plan H |
| `ClaudeQuery.toggleMcpServer(name:enabled:)` | Gap | Plan H |
| `ClaudeQuery.mcpServerStatus()` | Gap | Plan H |
| `ClaudeQuery.accountInfo()` | Gap | Could display account tier, limits |
| `ClaudeQuery.initializationResult()` | Gap | Plan E — session init info display |
| `ClaudeQuery.setPermissionMode()` | Deferred | SessionModeStrip changes mode per-query, not mid-stream |
| `ClaudeQuery.supportedCommands()` | Deferred | Tavern has its own command system |
| `ClaudeQuery.supportedAgents()` | Deferred | Tavern has its own servitor system |
| `ClaudeQuery.stopTask(taskId:)` | Deferred | No sub-task management in UI |
| `ClaudeQuery.setMcpServers()` | Deferred | MCP servers set at query start |
| `ClaudeQuery.streamInput()` | Deferred | Multi-turn streaming input |


### 2.5 MCP Server Infrastructure

| SDK Capability | Status | Notes |
|---|---|---|
| `SDKMCPServer` creation | Implemented | TavernMCPServer |
| `MCPTool` definition | Implemented | summon_servitor, dismiss_servitor |
| `JSONSchema` input validation | Implemented | Tool input schemas |
| `MCPToolResult.text()` | Implemented | Tool response formatting |
| `MCPToolResult.error()` | Implemented | Tool error reporting |
| `MCPToolAnnotations` | Deferred | No read-only/destructive hints set |
| `MCPContent.image` | Deferred | No image content in tool results |
| `MCPContent.resource` | Deferred | No resource URIs in tool results |
| External `MCPServerConfig` (stdio) | Deferred | No external MCP servers registered |
| External `MCPServerConfig` (SSE) | Deferred | No SSE MCP servers |
| External `MCPServerConfig` (HTTP) | Deferred | No HTTP MCP servers |
| Dynamic MCP server registration | Deferred | Servers set at query creation time |


### 2.6 Permission System

| SDK Capability | Status | Notes |
|---|---|---|
| `PermissionMode.default` | Implemented | Mapped in SessionModeStrip |
| `PermissionMode.acceptEdits` | Implemented | Mapped in SessionModeStrip |
| `PermissionMode.bypassPermissions` | Implemented | Mapped in SessionModeStrip |
| `PermissionMode.plan` | Implemented | Mapped in SessionModeStrip |
| `PermissionMode.dontAsk` | Implemented | Mapped in SessionModeStrip |
| `CanUseToolCallback` | Implemented | Plan mode gating + ExitPlanMode interception |
| `PermissionResult.allowTool()` | Implemented | Tool approval flow |
| `PermissionResult.denyTool()` | Implemented | Tool denial flow |
| `PermissionMode.delegate` | Deferred | No delegate mode use case |
| `PermissionResult.denyToolAndInterrupt()` | Deferred | No interrupt-on-deny use case |
| `PermissionResult.allowTool(updatedInput:)` | Deferred | No input rewriting use case |
| `PermissionResult.allowTool(permissionUpdates:)` | Deferred | No dynamic permission updates |
| `PermissionUpdate` (addRules, setMode, etc.) | Deferred | No dynamic permission rule changes |
| `PermissionRule` | Deferred | No granular per-tool rules |
| `ToolPermissionContext.suggestions` | Deferred | Not surfaced to user |
| `ToolPermissionContext.agentId` | Deferred | Not used in approval UI |


### 2.7 Hook System

| SDK Capability | Status | Notes |
|---|---|---|
| `onNotification` | Gap | Could surface CLI notifications in Tavern UI |
| `onPreToolUse` | Deferred | Tool approval handled via `canUseTool` callback |
| `onPostToolUse` | Deferred | No post-tool logging needed |
| `onPostToolUseFailure` | Deferred | Errors visible via stream events |
| `onUserPromptSubmit` | Deferred | No prompt interception needed |
| `onStop` | Deferred | Completion handled via stream events |
| `onSetup` | Deferred | No setup hook needed |
| `onTeammateIdle` | Deferred | Tavern manages servitor lifecycle directly |
| `onTaskCompleted` | Deferred | Mortal done-detection via response text |
| `onSessionStart` | Deferred | Session management at Tavern layer |
| `onSessionEnd` | Deferred | Session management at Tavern layer |
| `onSubagentStart` | Deferred | Tavern manages servitors directly |
| `onSubagentStop` | Deferred | Tavern manages servitors directly |
| `onPreCompact` | Deferred | No compact interception needed |
| `onPermissionRequest` | Deferred | Permission handled via `canUseTool` |
| Elicitation hooks | Deferred | Plan J (lowest priority) |
| Config change hooks | N/A | Tavern manages its own config |
| Worktree hooks | N/A | Tavern doesn't use worktrees |


### 2.8 Elicitation

| SDK Capability | Status | Notes |
|---|---|---|
| `options.onElicitation` callback | Gap | Plan J — MCP server elicitation routing |
| `ElicitationRequest` (serverName, message, schema) | Gap | Plan J |
| `ElicitationResult` (accept/decline/cancel) | Gap | Plan J |
| Elicitation hooks (pre/post) | Deferred | Plan J |


### 2.9 Sandbox & Security

| SDK Capability | Status | Notes |
|---|---|---|
| `SandboxSettings` | N/A | macOS app runs without sandbox entitlement |
| File system isolation | N/A | Trust boundary is at project directory level |


### 2.10 Session Info & History

| SDK Capability | Status | Notes |
|---|---|---|
| `SDKSessionInfo` (listing sessions) | Implemented | `ClaudeNativeSessionStorage` reads Claude's JSONL files |
| `SessionMessage` (reading messages) | Implemented | History display from native storage |
| `GetSessionMessagesOptions` | Implemented | Offset/limit for history loading |
| `ListSessionsOptions` | Implemented | Directory-scoped session listing |


### 2.11 Completion & Usage Data

| SDK Capability | Status | Notes |
|---|---|---|
| `sessionId` from result | Implemented | Session persistence |
| `usage.inputTokens` | Implemented | Token display in ChatHeader |
| `usage.outputTokens` | Implemented | Token display in ChatHeader |
| `usage.cacheReadInputTokens` | Implemented | Parsed but not displayed separately |
| `usage.cacheCreationInputTokens` | Implemented | Parsed but not displayed separately |
| `usage.costUsd` (per-turn) | Implemented | Accumulated in ChatTile |
| `totalCostUsd` | Implemented | Displayed in ChatHeader |
| `durationMs` | Implemented | Parsed in CompletionInfo |
| `stopReason` | Implemented | Parsed in CompletionInfo |
| `numTurns` | Implemented | Parsed in CompletionInfo |
| Per-model usage breakdown | Gap | Plan C — `modelUsage` dictionary not parsed |


### 2.12 Transport Layer

| SDK Capability | Status | Notes |
|---|---|---|
| `ProcessTransport` | N/A | Used internally by ClodKit, not directly by Tavern |
| Custom `Transport` conformance | N/A | Default process transport works |
| `Transport.isConnected` | N/A | Internal ClodKit concern |


---


## Gap Summary

Total SDK capabilities tracked: ~120

| Status | Count | ADR Violation? |
|--------|-------|----------------|
| Implemented | 62 | No |
| Gap | 16 | **Yes** |
| Deferred | 36 | **Yes** |
| Broken | 1 | **Yes** |
| N/A | 12 | No |

**Violations (require resolution):**

| Gap | Plan | Priority |
|-----|------|----------|
| Model selection (`model`, `setModel`, `supportedModels`) | D | High |
| Effort level (`effort`) | D | High |
| Thinking config (`thinking`, `maxThinkingTokens`) | D | High |
| Session resume (`options.resume`) | B | High |
| File rewind (`rewindFiles`) | G | Medium |
| MCP status & control (`mcpStatus`, `reconnect`, `toggle`) | H | Medium |
| Account info (`accountInfo`) | — | Medium |
| Budget cap (`maxBudgetUsd`) | — | Medium |
| Session init info (`initializationResult`) | E | Low |
| Notification hooks (`onNotification`) | — | Low |
| Elicitation (`onElicitation`) | J | Low |
| Per-model usage breakdown | C | Low |
| Fallback model (`fallbackModel`) | D | Low |
| Cache token display (separate) | — | Low |
| `SDKAssistantMessageError` surfacing | — | Low |


## Consequences

- Every ClodKit version bump includes a matrix update (atomic commit)
- `Gap` rows generate beads for tracking
- `Deferred` rows are reviewed quarterly
- The matrix serves as onboarding documentation for SDK capabilities
- Implementation plans (A–J) reference specific matrix rows


## References

- ClodKit v0.2.63-r0 source: `~/Documents/Projects/ClodKit`
- Implementation plan: `.claude/plans/noble-stargazing-glade.md`
- ADR-003 (Agent Mocking Strategy) — ServitorMessenger abstraction layer
- ADR-008 (Tileboard Architecture) — tile isolation from SDK details
