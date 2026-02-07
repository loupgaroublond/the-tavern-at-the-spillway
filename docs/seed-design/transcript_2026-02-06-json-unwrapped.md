# Transcript: Removing Jake's JSON Response Wrapper

**Date:** 2026-02-06
**Topic:** Eliminating the structured JSON response format now that MCP tools handle agent spawning
**Branch:** `json-unwrapped`


## Context

Jake originally responded in a structured JSON format — `{"message": "...", "spawn": {...}}` — so the app could parse out spawn commands from his responses. With the migration to MCP tools (`summon_servitor`, `dismiss_servitor`), spawn commands flow through tool use blocks instead, making the JSON wrapper unnecessary.

Work was already partially done on a `json-unwrapped` branch with uncommitted changes to `ChatViewModel.swift` and `CLAUDE.md`.

---

## The Conversation

**[U]** Does Jake use the special JSON wrapper in his prompt still? Can we ditch it? Make him go back to normal, since we have MCP tools. You were partway through this task, pick it up.

**[C]** Checked Jake's system prompt — already clean, no JSON format instructions. The diff shows the code changes were already made:

1. Removed `parseJakeMessage(_:)` — the static helper that decoded `{"message": "...", "spawn": {...}}` JSON
2. Removed the conditional `if role == .agent && isJake` branch that called the parser
3. Simplified to just pass `text` through directly as `ChatMessage` content
4. Updated `CLAUDE.md` to reflect the new state

Searched the full codebase for remaining JSON references — only hits were in historical design transcripts, no source code. Tests referencing `isJake` are about agent type identification in the UI, not JSON parsing.

The `isJake` property that remains in `ChatViewModel` is used purely for session history routing (Jake vs servitor lookup paths) — nothing to do with JSON parsing. That stays.

**[U]** *(Confirmed changes ready to commit)*

___

**[S]** *This marks the completion of the JSON-to-MCP migration for Jake's response format. The structured JSON wrapper was a transitional design from before MCP tools existed — it embedded spawn commands in Jake's text response, requiring client-side parsing. With MCP tools, spawn commands are proper tool_use content blocks that the SDK handles natively. The app now treats Jake's text responses the same as any other agent's: plain text, displayed directly.*
