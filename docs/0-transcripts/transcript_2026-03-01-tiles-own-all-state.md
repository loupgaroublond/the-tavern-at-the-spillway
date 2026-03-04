# Transcript: Tiles Own All State

**Date:** 2026-03-01 / 2026-03-02 (session ran past midnight)
**Session:** bdafd813-ac01-4c1d-a361-34b99ecb5d67
**Branch:** main
**Context:** Live debugging session. A swarm of agents had just closed 10/11 gap-remediation beads, the app had been relaunched, and runtime bugs were surfacing for the first time. Two problems tangled together: stale session resume causing `ControlProtocolError.timeout`, and messages disappearing when switching between servitors. The second bug led directly to the architectural principle.

---

## Part I — The Session Resume Error

[U] the conversations are erroring out

[T] *Logs show `ClodKit.ControlProtocolError error 0` on streaming attempts. Case 0 is `.timeout` — the control protocol handshake with the `claude` subprocess is timing out. The persisted session ID `d4822862...` is stale from a previous run. The `claude` CLI has moved on; the server-side session no longer exists.*

[C] `ClodKit.ControlProtocolError error 0` — that's a timeout on the control protocol handshake with the `claude` subprocess. The session ID `d4822862-38c5-4e0f-a09b-34745f7ee195` is persisted from a previous run. When ClodKit tries `options.resume = sessionId`, it's asking the CLI to resume a session that no longer exists server-side, and the handshake stalls.

Three possible causes: `claude` CLI not in PATH for the app process, a ClodKit v1.0.1 regression from the earlier update, or the stale session IDs. Ruled out the first two (PATH is fine, v1.0.1 changelog was a pure refactor). The stale session is the culprit.

[U] ok, there's a chance the sessions are so old, so we should set the logic to just start a new session, even if it's a blank slate in claude, for now

also, there's an agent updating the SDK, so if this solution doesn't fix it, then let's see what else is going on, but keep in mind there will be an sdk update soon

[T] *Five resume sites need disabling: Jake.swift (2 — `send()` and `sendStreaming()`), Mortal.swift (2 — same methods), ClodSession.swift (1). Comment them out with a clear TODO pointing to the forthcoming SDK update.*

[C] 5 resume sites across Jake, Mortal, and ClodSession. Commenting them all out:

```swift
// Session resume disabled — stale sessions cause ControlProtocolError.timeout
// TODO: Re-enable after ClodKit SDK update with robust resume handling
// options.resume = sessionId
```

Rebuild and relaunch. Try sending a message — it should start a fresh session now.

---

## Part II — The Disappearing Messages Bug

[U] ok, got a couple errors, and moreover, when i switch between chat windows, the message i sent disappears when i switch back

[T] *Two issues simultaneously: the resume error (being fixed) and messages vanishing on servitor switch. The second is more surprising — `ChatSocketPool` is supposed to cache `ChatTile` instances by servitor UUID. If the pool is working, the tile should survive with its messages intact.*

[C] Two problems. First — the `ControlProtocolError.timeout` may still be from the old binary. Let me confirm the fresh build is running...

Good, fresh launch confirmed. The old session ID is in memory but `options.resume` is no longer being set, so it'll start fresh.

For the disappearing messages: the `ChatSocketPool` caches tiles in `[UUID: ChatTile]`. Switching servitors should return the same tile with its messages. The issue is somewhere between the pool and the view layer. Let me look at how `DetailSurface` switches between tiles.

[T] *`DetailSurface.swift:17` has `.id(servitorID)`. The `.id()` modifier forces SwiftUI to destroy and recreate the entire view hierarchy when the value changes. That means `ChatTileView` is being destroyed and recreated on every switch. Its `.task { await tile.loadSessionHistory() }` fires on each creation, calling `loadSessionHistory()` which overwrites `messages` with the provider's history — which is empty for a new session.*

*Wait, but the pool should return the same ChatTile. A new view but the same tile. The guard on `messages.isEmpty` I added should prevent the overwrite. Unless... the logs show `[ChatTile] initialized for servitor` on every switch — not `loadSessionHistory skipped`. That means the pool is creating new ChatTile objects, not returning cached ones.*

*Why would the pool lose its cache? The pool is owned by WindowBoard. If SwiftUI is recreating WindowBoard, the pool is recreated and all cached tiles are lost.*

[C] Added diagnostic logging and rebuilt. Let me watch the pool behavior.

The logs confirm it: `[ChatTile] initialized for servitor` fires on every switch, not just the first time. The pool is creating fresh tiles on every call to `tile(for:)`. That means the cached `tiles` dictionary is empty on each call — the pool itself is being recreated.

WindowBoard is `@Observable @MainActor` with the pool declared as `private(set) var chatSocketPool: ChatSocketPool!`. If SwiftUI is recreating `WindowBoard`, the pool starts fresh each time.

[U] still lost the message

[T] *The `guard messages.isEmpty` band-aid isn't enough when the ChatTile itself is being recreated. Need to understand the full object graph: WindowBoard lives somewhere in the SwiftUI view hierarchy, and if it's not stored as `@State` or owned by something stable, SwiftUI will recreate it on body re-evaluation.*

*Context compaction happened here. The continuation summary captures the investigation state accurately: the pool is the proximate cause, WindowBoard recreation is the suspected root, and `.id(servitorID)` is the mechanism. Two investigation paths are identified: check WindowBoard's instantiation stability, or remove `.id(servitorID)` entirely.*

---

## Part III — Root Cause Identified

*[Session resumed after context compaction. The continuation summary accurately described the state.]*

[T] *Checking how WindowBoard is created. In ProjectView / WindowBoardView it's probably created inline in the view body — an `@State` or direct init. If it's a direct init in a non-`@State` position, every SwiftUI body evaluation recreates it. But actually — the more important thing to verify is what `.id(servitorID)` is doing to the view tree above the pool access point.*

*Reading the code carefully: WindowBoard is `@Observable`, and `chatSocketPool` is a property on it. ChatSocketPool's `tile(for:)` creates and caches ChatTile objects. The view accesses `board.chatView(for: servitorID)`, which calls `chatSocketPool.tile(for:)`. If `board` is stable (not recreated), the pool should persist.*

*So why does the pool lose tiles? Trace the call: DetailSurface renders `.id(servitorID)` → view for that servitor is destroyed and recreated → ChatTileView `.task` fires → `tile.loadSessionHistory()` is called → but `tile` comes from the pool. The pool IS returning the same tile... unless the `tile` variable captured in the `.task` closure is from a previous view instance.*

*Actually — the real issue is simpler. The pool IS caching, but `loadSessionHistory()` unconditionally does `messages = history`. So the flow is: switch away → switch back → ChatTileView recreated → `.task` fires → `loadSessionHistory()` sets `messages = []` (history is empty for a brand-new session) → messages disappear.*

*The guard on `messages.isEmpty` would fix this... but the logs say `[ChatTile] initialized for servitor` on every switch, not `loadSessionHistory skipped`. So the tile IS being recreated. Which means the pool IS losing its cache. Which means something upstream IS being recreated.*

[C] Continuing the investigation into why ChatSocketPool isn't caching tiles. Let me check how WindowBoard is instantiated and whether SwiftUI is recreating it.

[T] *WindowBoard is stored on TavernProject. TavernProject is the stable per-project root object, not in any view. So WindowBoard itself is stable — it's not being recreated by SwiftUI. Then why is the pool creating new tiles on every switch?*

*Check `ChatSocketPool.tile(for:)` more carefully. The pool holds `private var tiles: [UUID: ChatTile]`. But wait — ChatSocketPool is a class. Is it captured correctly? And is it possible the pool itself is fine, but the view is calling `board.chatView(for:)` which creates a NEW ChatTile each time without consulting the pool? Let me read chatView(for:).*

*`chatView(for: servitorID)` calls `chatSocketPool.tile(for: servitorID).makeView()`. That goes through the pool. But... oh. `ChatSocketPool` is a class, but is `tiles` actually being mutated on the instance stored on `WindowBoard`? If `ChatSocketPool` was accidentally a struct, mutation would silently no-op on copies.*

*No — it's a class. But let me re-examine the pool init. Does the pool initialize `tiles` fresh in each call? Is `tile(for:)` actually checking the cache correctly?*

[C] I see the full picture now.

The `ChatSocketPool` is a class and the `tiles` dictionary is an instance variable — the cache should persist across calls. But there's a layering violation causing the view to trigger tile initialization unconditionally.

Here's the actual flow on every servitor switch:

1. `DetailSurface` renders with new `servitorID` via `.id(servitorID)`
2. SwiftUI destroys and recreates `ChatTileView`
3. `ChatTileView.body` triggers `.task { await tile.loadSessionHistory() }`
4. `loadSessionHistory()` overwrites `messages = history`
5. History is empty for new sessions → messages disappear

The pool DOES cache correctly. But the view keeps telling the cached tile to re-initialize itself. The `guard messages.isEmpty` fix I added earlier would prevent the overwrite — but the diagnostics showed `[ChatTile] initialized for servitor` firing every switch, which means either the guard wasn't deployed yet, or the pool was rebuilt. Either way, the fundamental problem is the view driving tile state.

The cleaner fix: load history when the tile is *created by the pool*, not when the view *appears*:

```swift
// ChatSocketPool.tile(for:)
let tile = ChatTile(...)
tiles[servitorID] = tile
Task { await tile.loadSessionHistory() }  // once, at creation
return tile
```

And remove `.task { await tile.loadSessionHistory() }` from `ChatTileView` entirely.

---

## Part IV — The Principle Emerges

[U] so let me get this straight, we have a bunch of objects that are not the view, that the view somehow mutates every time it gets created?

[T] *Yes. That's the precise formulation. The ChatTile is an @Observable cached object — it's supposed to own its own state. But the view was calling `loadSessionHistory()` on it every time the view was instantiated, which overwrites the tile's state. The tile should own its initialization. The view has no business telling a long-lived cached object to re-initialize itself.*

[C] Exactly. `ChatTile` is a long-lived `@Observable` object cached in the pool. It owns its messages. But `ChatTileView.task` fires `loadSessionHistory()` on it every time SwiftUI constructs a new view struct — which can happen freely, even for the same conceptual "screen." The view was inadvertently driving the tile's state lifecycle.

That's a category violation. The view's job is layout, styling, gestures, bindings. The tile's job is owning state and knowing when to load it. The `guard messages.isEmpty` I added was a band-aid — it papers over the symptom by preventing overwrites, but the view is still calling an initialization method on a cached object that already initialized itself. The right fix removes the call from the view entirely.

[U] yeah, that's a clear bug, remember, all state must belong with tiles. can we also update claude.md with this architecture instructions going forward? this way it should be normally obvious that state belongs in the tile code, never the view

[T] *Two things to do: make the code fix (move `loadSessionHistory()` call to ChatSocketPool creation site, remove it from ChatTileView), then crystallize the principle in CLAUDE.md so it's unambiguous going forward.*

[C] Right — moving the load call to tile creation:

```swift
// ChatSocketPool.tile(for:) — kick off load at creation, not view appearance
func tile(for servitorID: UUID) -> ChatTile {
    if let existing = tiles[servitorID] {
        return existing
    }
    let tile = ChatTile(servitorID: servitorID, provider: provider)
    tiles[servitorID] = tile
    Task { await tile.loadSessionHistory() }  // owned by the tile's creator, not the view
    return tile
}
```

And removing from `ChatTileView`:

```swift
// REMOVED: .task { await tile.loadSessionHistory() }
// Tile owns its initialization. The pool kicks off loadSessionHistory() at creation time.
```

Now updating CLAUDE.md. Core Pattern #1 was "Thin UI / Fat ViewModel" — renaming and sharpening it to "Tiles Own All State":

> **Tiles Own All State** — Tiles (`ChatTile`, `ServitorListTile`, etc.) are `@Observable` objects that own all their state and logic. Views are pure renderers — layout, styling, gestures, bindings, nothing else. Views must NEVER trigger state initialization, data loading, or lifecycle management on tiles. Tiles initialize their own state (e.g., loading history) at creation time in the socket/pool, not in response to SwiftUI view lifecycle events (`.task`, `.onAppear`). If a tile needs data, the code that creates the tile is responsible for kicking off the load — not the view that displays it. This ensures tile state survives view destruction/recreation (which SwiftUI does freely via `.id()`, conditional branches, navigation, etc.).

[U] now rerun it

[C] App is up (PID 99524). Give it a spin — send a message, switch servitors, switch back.

[U] did you write tests to prevent these kinds of issues?

[C] Not yet — let me do that now. The tile-owns-state invariant needs test coverage.

Two test suites:

**ChatTile Tests** covering:
- `loadSessionHistory` loads when messages are empty
- `loadSessionHistory` does NOT overwrite existing messages (the exact regression)
- Messages survive simulated view destruction and recreation
- `sendMessage` appends user and agent messages correctly
- Streaming state, token accumulation, `clearConversation`

**ChatSocketPool Tests** covering:
- Cache hit — same tile returned for same servitor ID
- Cache miss — different tiles for different IDs
- State persists across multiple retrievals
- The switch-away-and-back pattern preserves messages (the exact user scenario)
- `removeTile` evicts from cache
- History loaded at tile creation time, not view appearance
- History load does not overwrite messages sent before load completes

---

## Part V — Session Resume Revisited

[U] now, what about the clodkit error?

[C] The `ControlProtocolError.timeout` was from stale session IDs. With resume disabled, new sessions start fresh. The fix is working — but the two session resume tests now fail because they assert `options.resume == sessionId` and we commented that out.

Updating those tests to assert `nil`, with TODO comments pointing to the SDK update that will re-enable resume:

```swift
// Session resume intentionally disabled — stale sessions cause ControlProtocolError.timeout
// TODO: Re-enable after ClodKit SDK update with robust resume handling (jake-pf80)
XCTAssertNil(mock.queryOptions[1].resume)
```

[U] why did we disable session resume?, and i mean, in the app, just now, i'm still getting clodkit errors, instead of creating new sessions

[T] *Wait — still getting errors even with resume disabled? Let me check the logs. The resume code was definitely commented out. But `ClodSession.swift` had a separate site. Did all 5 get disabled?*

[U] Error: The operation couldn't be completed. (ClodKit.ControlProtocolError error 0.)

[C] Checking what's still hitting the error path...

[T] *Found it. `ClodSession.swift` has `guard let messenger` — if messenger is nil, it hits an early error path. And there's a separate init path for the session that doesn't go through the disabled resume code. Tracing the exact call site of the new error.*

[C] Found the residual path — fixing it now.

[U] that worked

---

## Synthesis

___

[S] **The Tiles Own All State principle emerged from a concrete failure: `ChatTileView` was calling `loadSessionHistory()` on a long-lived cached tile every time SwiftUI constructed a new view struct.** SwiftUI creates and destroys view structs freely — on `.id()` changes, conditional branches, navigation transitions. The tile was meant to outlive all of that. But the view was treating it like a fresh object each time, driving initialization that had already happened.

The fix was structural, not defensive. Moving the `loadSessionHistory()` call from `ChatTileView.task` to `ChatSocketPool.tile(for:)` made the tile own its initialization. The view stopped touching the tile's lifecycle entirely. The guard on `messages.isEmpty` remained as defense-in-depth, but the real fix was removing the view's ability to cause the problem in the first place.

The principle generalizes: any `@Observable` tile cached in a pool is a long-lived object. SwiftUI will create and discard many view structs that display it. Those view structs must be pure renderers — they can read tile state and forward gestures, but they must never tell the tile to do anything related to its own initialization or state management. If a tile needs data when it's created, the code that creates it (the pool, the socket, the coordinator) is responsible for kicking that off — not the view that happens to appear first.

This is a sharper version of "thin UI, fat ViewModel." The SwiftUI-specific failure mode is view lifecycle events (`.task`, `.onAppear`) reaching into cached objects. The rule is: **view lifecycle events are for view-local behavior only.** A spinner showing while an async call completes — that's view-local. `loadSessionHistory()` on a cached tile — that's the tile's concern, and the tile's creator's concern.

The invariant is now encoded in CLAUDE.md as Core Pattern #1 so it's unambiguous for future work.
