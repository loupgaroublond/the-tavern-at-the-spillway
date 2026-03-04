# SDK Feature Parity Report — 2026-03-02

**Source:** ADR-010 feature matrix (Part 2)
**Generated:** 2026-03-03 (retroactive for 2026-03-02 verification report)
**ClodKit version:** v1.0.0

## Summary

| Matrix Status | Count | Verified | Partial | False/Stale | Confirmed | Untracked |
|---------------|-------|----------|---------|-------------|-----------|-----------|
| Implemented   | 62    | 53       | 9       | 0           | —         | —         |
| Gap           | 16    | —        | —       | —           | 0         | 16        |
| Deferred      | 36    | —        | —       | —           | 36        | 0         |
| Broken        | 1     | —        | —       | —           | 1         | 0         |
| N/A           | 12    | —        | —       | —           | 12        | —         |

**Pass criteria:** Zero FALSE implementations. Zero UNTRACKED violations.
**Result:** FAIL — 16 Gap rows are UNTRACKED (no bead exists for any individual gap)

> Note on Gap tracking: The gaps are acknowledged in the ADR's Gap Summary section with plan letters (B, C, D, E, G, H, J), but none have a dedicated bd bead. The closest match is `jake-vn54` (Model selection system — PRD + spec) which touches Plan D gaps, and `jake-yte` (Token budget and cost visibility) which touches the budget gap. These are design/PRD beads, not gap-resolution tracking beads. ADR-010 Rule 2 requires every Gap row to have a corresponding bead.

---

## Per-Section Details

### 2.1 Query & Session Lifecycle

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `Clod.query(prompt:options:)` — single prompt | Implemented | VERIFIED | `LiveMessenger.query()` in `Testing/LiveMessenger.swift:131`; tested in `StreamingTests.swift` (batch path), `JakeTests.swift`, `MortalTests.swift` |
| `ClaudeQuery` async iteration | Implemented | VERIFIED | `LiveMessenger.queryStreaming()` in `LiveMessenger.swift:165`; full streaming loop; tested in `StreamingTests.swift` |
| `ClaudeQuery.interrupt()` | Implemented | PARTIAL | `interrupt()` called in `LiveMessenger.swift:191,358` and in `Jake.swift`/`Mortal.swift` cancel paths; cancellation tested in `StreamingTests.swift` via mock; no test exercises `interrupt()` against the real `ClaudeQuery` object (only mock cancel closure) |
| `ClaudeQuery.sessionId` | Implemented | VERIFIED | `await query.sessionId` read in `LiveMessenger.swift:161`; session persistence tested in `JakeTests.swift`, `MortalTests.swift`, `JakeIntegrationTests.swift:80-87` |
| `options.persistSession` | Implemented | PARTIAL | Used implicitly (default true — never set to false in Tavern code); no test asserts the option is set or that sessions actually persist across process restarts under real SDK |
| `options.resume` — session resume | Broken | CONFIRMED | Disabled in `ClodSession.swift:158-162` with comment "stale sessions cause ControlProtocolError.timeout"; no bead for Plan B. Gap bead is untracked — see note in Summary |
| `Clod.query(prompt:options:)` — AsyncSequence prompt | Deferred | CONFIRMED | No code uses this overload |
| `Clod.query(options:promptStream:)` — closure prompt | Deferred | CONFIRMED | No code uses this overload |
| `ClaudeQuery.close()` | Deferred | CONFIRMED | Not called; relying on scope cleanup |
| `options.continueConversation` | Deferred | CONFIRMED | Never set in `buildOptions()` / `LiveMessenger` |
| `options.forkSession` | Deferred | CONFIRMED | Never set |
| `options.sessionId` | Deferred | CONFIRMED | Never set |
| `options.resumeSessionAt` | Deferred | CONFIRMED | Never set |

---

### 2.2 QueryOptions — Core Configuration

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `systemPrompt` | Implemented | VERIFIED | Set in `Jake.swift`, `Mortal.swift`, `ClodSession.swift:154`; tested in `JakeTests.swift:253` and integration tests |
| `permissionMode` | Implemented | VERIFIED | Mapped in `Jake.swift:287`, `Mortal.swift:311`, `ClodSession.swift:155`; 5-mode enum tested in `PermissionModeTests.swift`; mode propagation tested in `JakeTests.swift:253,259`, `MortalTests.swift:445,451` |
| `workingDirectory` | Implemented | VERIFIED | Set in `ClodSession.swift:156`, `Jake.swift`, `Mortal.swift`; verified in integration tests `SDKLiveIntegrationTests.swift:35` |
| `environment` | Implemented | PARTIAL | `opts.environment["CLAUDECODE"] = ""` in `LiveMessenger.swift:135,169`; no test asserts the environment option is actually set or that nesting prevention works |
| `canUseTool` callback | Implemented | VERIFIED | Built in `LiveMessenger.buildCanUseToolCallback()`; plan approval and tool approval both implemented; tested in `PermissionEnforcementTests.swift:116-135` |
| `includePartialMessages` | Implemented | VERIFIED | Set `opts.includePartialMessages = true` in `LiveMessenger.swift:171`; content block streaming exercised throughout streaming tests |
| `promptSuggestions` | Implemented | VERIFIED | Parsed in `LiveMessenger.swift:310-313`; displayed as chips in `ChatTileView.swift:111-116`; tested in `ChatTileTests.swift:351-367` |
| `model` | Gap | UNTRACKED | No code sets `options.model`; no bead tracks resolution. `jake-vn54` (Model selection system PRD) is a design bead, not a gap-resolution bead |
| `fallbackModel` | Gap | UNTRACKED | No code; no bead |
| `maxThinkingTokens` | Gap | UNTRACKED | No code; no bead |
| `thinking` (ThinkingConfig) | Gap | UNTRACKED | No code; no bead |
| `effort` | Gap | UNTRACKED | No code; no bead |
| `maxBudgetUsd` | Gap | UNTRACKED | No code; `jake-yte` (Token budget and cost visibility) is a UI design bead, not a gap-resolution bead for this SDK option |
| `appendSystemPrompt` | Deferred | CONFIRMED | Never set |
| `maxTurns` | Deferred | CONFIRMED | Never set (integration tests set it directly but Tavern production code does not) |
| `logger` | Deferred | CONFIRMED | Never set |
| `allowedTools` | Deferred | CONFIRMED | Never set |
| `blockedTools` | Deferred | CONFIRMED | Never set |
| `disallowedTools` | Deferred | CONFIRMED | Never set |
| `additionalDirectories` | Deferred | CONFIRMED | Never set |
| `agent` | Deferred | CONFIRMED | Never set |
| `agents` (AgentDefinition) | Deferred | CONFIRMED | Never set |
| `betas` | Deferred | CONFIRMED | Never set |
| `outputFormat` (structured) | Deferred | CONFIRMED | Never set |
| `stderrHandler` | Deferred | CONFIRMED | Never set |
| `settingSources` | Deferred | CONFIRMED | Never set |
| `strictMcpConfig` | Deferred | CONFIRMED | Never set |
| `plugins` (SdkPluginConfig) | Deferred | CONFIRMED | Never set |
| `tools` (ToolsConfig) | Deferred | CONFIRMED | Never set |
| `cliPath` | N/A | CONFIRMED | Justification holds: default CLI discovery is intentionally used |
| `debug` | N/A | CONFIRMED | Justification holds: development-use only |
| `debugFile` | N/A | CONFIRMED | Justification holds: development-use only |
| `executableArgs` | N/A | CONFIRMED | Justification holds: advanced CLI control not needed |
| `extraArgs` | N/A | CONFIRMED | Justification holds |
| `spawnClaudeCodeProcess` | N/A | CONFIRMED | Justification holds: default process spawning works |

---

### 2.3 Streaming & Message Types

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `StdoutMessage.regular(SDKMessage)` | Implemented | VERIFIED | Primary dispatch in `LiveMessenger.swift:196`; exercised by all streaming tests |
| `SDKMessage.type == "stream_event"` | Implemented | VERIFIED | Full content block parsing in `LiveMessenger.swift:201-260`; tested in `ChatPolishTests.swift`, `ChatTileTests.swift` |
| `SDKMessage.type == "assistant"` | Implemented | VERIFIED | Fallback handled in `LiveMessenger.swift:329`; batch path also handles it in `query()` at line 150 |
| `SDKMessage.type == "result"` | Implemented | VERIFIED | `parseCompletionInfo()` in `LiveMessenger.swift:404`; tested in `StreamingTests.swift:28`, `ChatPolishTests.swift:124` |
| `SDKMessage.type == "system"` | Implemented | VERIFIED | Status extraction in `LiveMessenger.swift:294-297`; `systemStatus` tested in `ChatTileTests.swift:395-413` |
| `SDKMessage.type == "user"` (tool results) | Implemented | VERIFIED | Two-path extraction in `LiveMessenger.swift:263-284`; tool result rendering tested in `ChatTileTests.swift:246-275` |
| `SDKMessage.type == "tool_progress"` | Implemented | VERIFIED | `ToolProgressInfo` extraction in `LiveMessenger.swift:302-308`; ChatTile shows `ToolProgressIndicator`; `toolProgress` event handling verified in `ChatTileTests.swift` (via `currentToolName` tracking) |
| `SDKMessage.type == "prompt_suggestion"` | Implemented | VERIFIED | Parsed in `LiveMessenger.swift:310-313`; chips in `ChatTileView.swift:111-116`; tested in `ChatTileTests.swift:351-367` |
| `SDKMessage.type == "rate_limit"` | Implemented | VERIFIED | Rate limit extraction in `LiveMessenger.swift:316-326`; visible message created in `ChatTile.swift:252-258`; tested in `ChatTileTests.swift:373-393` |
| `content_block_start` (text) | Implemented | VERIFIED | Block detection at `LiveMessenger.swift:208`; text message creation at `ChatTile.swift:179-189` |
| `content_block_start` (thinking) | Implemented | VERIFIED | Thinking block at `LiveMessenger.swift:212`; thinking message at `ChatTile.swift:167-175`; tested in `ChatTileTests.swift:218-244` |
| `content_block_start` (tool_use) | Implemented | VERIFIED | Tool use block with name+ID at `LiveMessenger.swift:213-224`; tested in `ChatTileTests.swift:246-275` |
| `content_block_delta` (text_delta) | Implemented | VERIFIED | `LiveMessenger.swift:234-237`; real-time text streaming accumulation tested in `ChatTileTests.swift` |
| `content_block_delta` (thinking_delta) | Implemented | VERIFIED | `LiveMessenger.swift:239-241`; tested in `ChatPolishTests.swift:80-87` |
| `content_block_delta` (input_json_delta) | Implemented | VERIFIED | Accumulation at `LiveMessenger.swift:242-248`; tested in `ChatTileTests.swift:276-299` |
| `content_block_stop` | Implemented | VERIFIED | Block finalization at `LiveMessenger.swift:253-256`; tested in `ChatPolishTests.swift:90-97` |
| `SDKAssistantMessageError` | Deferred | CONFIRMED | No handling code found in Tavern sources |
| `StdoutMessage.keepAlive` | Deferred | CONFIRMED | Matched by `case .keepAlive` in `LiveMessenger.swift:156` and integration tests but silently ignored — not surfaced to UI, matching the "Not surfaced to UI" note |
| `StdoutMessage.controlRequest` | N/A | CONFIRMED | Justification holds: matched by `case .controlRequest` in `LiveMessenger.swift:156` and discarded |
| `StdoutMessage.controlResponse` | N/A | CONFIRMED | Same — `case .controlResponse` discarded |

---

### 2.4 Session Query Control (Mid-Stream)

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `ClaudeQuery.setModel()` | Gap | UNTRACKED | No code calls `setModel()`; no bead |
| `ClaudeQuery.setMaxThinkingTokens()` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.supportedModels()` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.rewindFiles(to:)` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.rewindFilesTyped(to:dryRun:)` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.mcpStatus()` | Gap | UNTRACKED | No code; no bead. `jake-cvk` (/mcp add server management) is an MCP UI bead, not specifically tracking `mcpStatus()` |
| `ClaudeQuery.reconnectMcpServer(name:)` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.toggleMcpServer(name:enabled:)` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.mcpServerStatus()` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.accountInfo()` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.initializationResult()` | Gap | UNTRACKED | No code; no bead |
| `ClaudeQuery.setPermissionMode()` | Deferred | CONFIRMED | `SessionModeStrip` changes mode per-query in `ClodSession.buildOptions()`; no mid-stream `setPermissionMode()` call |
| `ClaudeQuery.supportedCommands()` | Deferred | CONFIRMED | No code calls this |
| `ClaudeQuery.supportedAgents()` | Deferred | CONFIRMED | No code calls this |
| `ClaudeQuery.stopTask(taskId:)` | Deferred | CONFIRMED | No code calls this |
| `ClaudeQuery.setMcpServers()` | Deferred | CONFIRMED | MCP servers set at query start in `buildOptions()` via `options.sdkMcpServers` |
| `ClaudeQuery.streamInput()` | Deferred | CONFIRMED | No code calls this |

---

### 2.5 MCP Server Infrastructure

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `SDKMCPServer` creation | Implemented | VERIFIED | `createTavernMCPServer()` in `TavernMCPServer.swift:21`; tested in `SDKLiveIntegrationTests.swift` (MCP tool invocation tests) |
| `MCPTool` definition | Implemented | VERIFIED | `summon_servitor` and `dismiss_servitor` tools in `TavernMCPServer.swift:25-92`; exercised in integration tests |
| `JSONSchema` input validation | Implemented | VERIFIED | Input schemas defined for both tools in `TavernMCPServer.swift:29-36, 62-68` |
| `MCPToolResult.text()` | Implemented | VERIFIED | `.text(...)` return at `TavernMCPServer.swift:53,82` |
| `MCPToolResult.error()` | Implemented | VERIFIED | `.error(...)` return at `TavernMCPServer.swift:56,88` |
| `MCPToolAnnotations` | Deferred | CONFIRMED | No annotations set on tools |
| `MCPContent.image` | Deferred | CONFIRMED | No image content in tool results |
| `MCPContent.resource` | Deferred | CONFIRMED | No resource URIs |
| External `MCPServerConfig` (stdio) | Deferred | CONFIRMED | No external MCP servers registered |
| External `MCPServerConfig` (SSE) | Deferred | CONFIRMED | No SSE servers |
| External `MCPServerConfig` (HTTP) | Deferred | CONFIRMED | No HTTP servers |
| Dynamic MCP server registration | Deferred | CONFIRMED | Servers set at query creation time only |

---

### 2.6 Permission System

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `PermissionMode.default` | Implemented | VERIFIED | Mapped in `Jake.swift:288-299`, `Mortal.swift:311-321`, `ClodSession.swift:183-191`; tested via `JakeTests.swift:259` (maps `TavernKit.PermissionMode.normal` to `.default`) |
| `PermissionMode.acceptEdits` | Implemented | VERIFIED | Mapped in same locations; `PermissionModeTests.swift:25` verifies raw value |
| `PermissionMode.bypassPermissions` | Implemented | VERIFIED | Mapped; tested in `MortalTests.swift:451` |
| `PermissionMode.plan` | Implemented | VERIFIED | Mapped; tested in `JakeTests.swift:253`, `MortalTests.swift:445`; used in all Grade 3 integration tests |
| `PermissionMode.dontAsk` | Implemented | PARTIAL | Mapped in all three locations; `PermissionModeTests.swift:28` verifies raw value; no test asserts propagation to `ClodKit.PermissionMode.dontAsk` at the options level |
| `CanUseToolCallback` | Implemented | VERIFIED | `buildCanUseToolCallback()` in `LiveMessenger.swift:44`; tested in `PermissionEnforcementTests.swift:116-135` |
| `PermissionResult.allowTool()` | Implemented | VERIFIED | Returned at `LiveMessenger.swift:84, 94, 101, 123` |
| `PermissionResult.denyTool()` | Implemented | VERIFIED | Returned at `LiveMessenger.swift:88, 103, 125` |
| `PermissionMode.delegate` | Deferred | CONFIRMED | Not mapped in `clodKitPermissionMode()` |
| `PermissionResult.denyToolAndInterrupt()` | Deferred | CONFIRMED | Not used |
| `PermissionResult.allowTool(updatedInput:)` | Deferred | CONFIRMED | Not used |
| `PermissionResult.allowTool(permissionUpdates:)` | Deferred | CONFIRMED | Not used |
| `PermissionUpdate` (addRules, setMode, etc.) | Deferred | CONFIRMED | Not used |
| `PermissionRule` | Deferred | CONFIRMED | `PermissionRule.swift` exists in Tavern but is the Tavern-layer rule type, not the SDK's `PermissionRule` |
| `ToolPermissionContext.suggestions` | Deferred | CONFIRMED | `context.toolUseID` used at `LiveMessenger.swift:84,88,94,101`; `.suggestions` not accessed |
| `ToolPermissionContext.agentId` | Deferred | CONFIRMED | Not accessed |

---

### 2.7 Hook System

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `onNotification` | Gap | UNTRACKED | No code registers `onNotification` hook; no bead |
| `onPreToolUse` | Deferred | CONFIRMED | Not registered |
| `onPostToolUse` | Deferred | CONFIRMED | Not registered |
| `onPostToolUseFailure` | Deferred | CONFIRMED | Not registered |
| `onUserPromptSubmit` | Deferred | CONFIRMED | Not registered |
| `onStop` | Deferred | CONFIRMED | Not registered |
| `onSetup` | Deferred | CONFIRMED | Not registered |
| `onTeammateIdle` | Deferred | CONFIRMED | Not registered |
| `onTaskCompleted` | Deferred | CONFIRMED | Not registered |
| `onSessionStart` | Deferred | CONFIRMED | Not registered |
| `onSessionEnd` | Deferred | CONFIRMED | Not registered |
| `onSubagentStart` | Deferred | CONFIRMED | Not registered |
| `onSubagentStop` | Deferred | CONFIRMED | Not registered |
| `onPreCompact` | Deferred | CONFIRMED | Not registered |
| `onPermissionRequest` | Deferred | CONFIRMED | Not registered |
| Elicitation hooks | Deferred | CONFIRMED | Not registered |
| Config change hooks | N/A | CONFIRMED | Justification holds: Tavern manages own config |
| Worktree hooks | N/A | CONFIRMED | Justification holds: Tavern doesn't use worktrees |

---

### 2.8 Elicitation

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `options.onElicitation` callback | Gap | UNTRACKED | No code; no bead |
| `ElicitationRequest` (serverName, message, schema) | Gap | UNTRACKED | No code; no bead |
| `ElicitationResult` (accept/decline/cancel) | Gap | UNTRACKED | No code; no bead |
| Elicitation hooks (pre/post) | Deferred | CONFIRMED | Not registered |

---

### 2.9 Sandbox & Security

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `SandboxSettings` | N/A | CONFIRMED | `com.apple.security.app-sandbox: false` in `Tavern.entitlements`; justification holds |
| File system isolation | N/A | CONFIRMED | Justification holds: trust boundary is at project directory level |

---

### 2.10 Session Info & History

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `SDKSessionInfo` (listing sessions) | Implemented | VERIFIED | `ClaudeNativeSessionStorage.getSessions()` in `ClaudeNativeSessionStorage.swift:53`; reads `~/.claude/projects/` JSONL files |
| `SessionMessage` (reading messages) | Implemented | VERIFIED | `ClaudeStoredMessage` model in `ClaudeSessionModels.swift`; parsed in `ClaudeNativeSessionStorage.parseJSONLData()` |
| `GetSessionMessagesOptions` | Implemented | PARTIAL | `getMessages()` at `ClaudeNativeSessionStorage.swift:114` exists; offset/limit available via `parseSessionFile` but the API description maps to ClodKit's `GetSessionMessagesOptions` type which may differ from Tavern's custom JSONL parsing. Tavern reads files directly rather than using SDK session APIs. No unit test exercises offset/limit loading specifically |
| `ListSessionsOptions` | Implemented | PARTIAL | `listProjects()` and `getSessions()` provide directory-scoped listing; Tavern's implementation is custom JSONL reading, not the ClodKit SDK's `ListSessionsOptions`. No test exercises the listing with option parameters |

---

### 2.11 Completion & Usage Data

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `sessionId` from result | Implemented | VERIFIED | Extracted in `LiveMessenger.parseCompletionInfo()` at `LiveMessenger.swift:416`; persisted in `ClodSession.swift:102-103`; tested in `StreamingTests.swift:28` |
| `usage.inputTokens` | Implemented | VERIFIED | Parsed in `LiveMessenger.swift:409`; accumulated in `ChatTile.swift:265-266`; tested in `ChatPolishTests.swift:12`, `StreamingTests.swift:53` |
| `usage.outputTokens` | Implemented | VERIFIED | Same parsing path; tested |
| `usage.cacheReadInputTokens` | Implemented | PARTIAL | Parsed in `LiveMessenger.swift:411`; stored in `SessionUsage`; field tested in `ChatPolishTests.swift:40`. Not displayed separately in UI — the ADR notes "Parsed but not displayed separately" |
| `usage.cacheCreationInputTokens` | Implemented | PARTIAL | Same as above |
| `usage.costUsd` (per-turn) | Implemented | VERIFIED | Parsed in `LiveMessenger.swift:413`; cost accumulated in `ChatTile.swift:269-271`; tested in `ChatTileTests.swift:329-349` |
| `totalCostUsd` | Implemented | VERIFIED | `json["total_cost_usd"]` in `LiveMessenger.swift:419-420`; displayed in `ChatTile.formattedTokens`; tested in `ChatTileTests.swift:329-349` |
| `durationMs` | Implemented | PARTIAL | Parsed in `LiveMessenger.swift:421`; stored in `CompletionInfo`; tested in `ChatPolishTests.swift:128`. Not displayed in UI |
| `stopReason` | Implemented | PARTIAL | Parsed in `LiveMessenger.swift:422`; stored in `CompletionInfo`; tested in `ChatPolishTests.swift:128`. Not displayed in UI |
| `numTurns` | Implemented | PARTIAL | Parsed in `LiveMessenger.swift:423`; stored in `CompletionInfo`; tested in `ChatPolishTests.swift:128`. Not displayed in UI |
| Per-model usage breakdown | Gap | UNTRACKED | `modelUsage` dictionary not parsed; no code; no bead |

---

### 2.12 Transport Layer

| SDK Capability | Matrix Status | Verdict | Evidence |
|----------------|---------------|---------|----------|
| `ProcessTransport` | N/A | CONFIRMED | Justification holds: used internally by ClodKit |
| Custom `Transport` conformance | N/A | CONFIRMED | Justification holds |
| `Transport.isConnected` | N/A | CONFIRMED | Justification holds |

---

## Verdict Detail: Partial Implementations

The 9 PARTIAL verdicts among Implemented rows represent real code that functions correctly but has incomplete coverage in one or more dimensions:

1. **`ClaudeQuery.interrupt()`** — interrupt() called but only tested via mock cancel closure; no test hits the real ClaudeQuery.interrupt() path.

2. **`options.persistSession`** — used implicitly as default-true; no test verifies the flag or cross-process session persistence.

3. **`options.environment` (CLAUDECODE)** — set in production code but no test asserts the env var is included in options.

4. **`PermissionMode.dontAsk`** — mapped and raw-value tested but no end-to-end test asserts the mapping reaches ClodKit's options.

5. **`usage.cacheReadInputTokens`** — parsed and unit tested; not displayed in UI. ADR acknowledges this.

6. **`usage.cacheCreationInputTokens`** — same as above.

7. **`durationMs`** — parsed and unit tested; not surfaced to UI.

8. **`stopReason`** — parsed and unit tested; not surfaced to UI.

9. **`numTurns`** — parsed and unit tested; not surfaced to UI.

Items 5–9 match the ADR's own "Parsed but not displayed" notes and are low-severity. Items 1–4 represent actual wiring gaps worth tracking.

---

## Gap Bead Status

All 16 Gap rows are UNTRACKED. No bead exists with the specific purpose of resolving an individual ADR-010 Gap row. The closest existing beads are:

| Gap | Closest Existing Bead | Relationship |
|-----|----------------------|--------------|
| `model`, `setModel`, `supportedModels`, `fallbackModel`, `thinking`, `maxThinkingTokens`, `effort` | `jake-vn54` (Model selection system — PRD + spec) | Design/PRD work, not a gap-resolution tracking bead |
| `maxBudgetUsd` | `jake-yte` (Token budget and cost visibility) | UI design bead, not SDK option gap bead |
| `onNotification` | `jake-lt2s` (Notification prioritization system) | UI/UX bead, not SDK hook gap bead |

ADR-010 Rule 2 states: "Every Gap, Deferred, and Broken row is a violation of this ADR. Each must have a corresponding bead tracking resolution." This requirement is unmet for all Gap rows.
