# Transcript: Async Primitive Strategy

**Date:** 2026-01-24
**Session:** Architecture review, async primitive decision, ADR update


## Architecture Fitness Review

**[U]** "have a look at ADR-001 and the PRD — from your perspective, does this seem like a natural fit of tools for you to implement it in? or is there a design pattern here that is likely to trip you up"

*[T] User asking for honest assessment of implementation friction before building.*

**[C]** Identified natural fits:
- Protocol-based abstractions (`DocStore`, `MessageBus`) — testable with mocks
- Thin UI / Fat ViewModel — all logic unit-testable without SwiftUI
- File-based state — inspectable, debuggable, no magic
- Clear layer boundaries with explicit dependency rules

**[C]** Identified friction points:

1. **Supervisor Tree in Swift** — Erlang/OTP pattern in a language without native support. Need clear specs for: failure propagation, bubbling semantics, child lifecycle management.

2. **Swift 6 Strict Concurrency + Sidecar** — Two-actor-per-agent pattern multiplies isolation boundaries. `Sendable` conformance constraints on message payloads.

3. **Combine + async/await Bridging** — Architecture uses both. Converting between them is error-prone around cancellation and backpressure.

4. **FSEvents for Doc Store Watching** — File watching has its own threading model that needs careful bridging into actor system.


## Async Primitive Decision

**[U]** "how would we decide on the best async primitives in this instance?"

**[C]** Laid out decision framework:

| Aspect | Combine | AsyncStream |
|--------|---------|-------------|
| SwiftUI integration | Native (`@Published`) | Requires bridging |
| Actor isolation | Awkward (not `Sendable`) | Native fit |
| Operators | Rich (50+) | Sparse |
| Cancellation | `AnyCancellable` bags | Structured (task hierarchy) |

The question isn't "which is better" but "where does each live?"

```
┌─────────────────────────────────┐
│ SwiftUI Views                   │  ← Combine required
├─────────────────────────────────┤
│ ViewModels                      │  ← Bridge layer
├─────────────────────────────────┤
│ Agent Layer (actors)            │  ← async/await preferred
├─────────────────────────────────┤
│ Infrastructure                  │  ← async/await natural
└─────────────────────────────────┘
```


## The SDK Reality Check

**[U]** "why do you say 'likely'? we have the SDK here..."

*[T] User correctly called out speculation. Should have checked the actual code.*

**[C]** Examined `ClaudeCodeSDK`:

```swift
@frozen public enum ClaudeCodeResult {
    case text(String)
    case json(ResultMessage)
    case stream(AnyPublisher<ResponseChunk, Error>)  // Combine!
}
```

The SDK has already made the choice: **Combine for streaming, async/await for batch.**


## What is AsyncStream?

**[U]** "also, what's asyncstream?"

**[C]** Swift's built-in primitive for producing async values over time. The async/await equivalent of a Combine publisher.

```swift
// Creating
let stream = AsyncStream<Int> { continuation in
    continuation.yield(1)
    continuation.yield(2)
    continuation.finish()
}

// Consuming
for await value in stream {
    print(value)
}
```

Before Swift concurrency: Combine or callbacks. AsyncStream fills the gap — a sequence you can `for await` over.


## Which is "The Future"?

**[U]** "which one is more likely 'the future'"

**[C]** AsyncStream/AsyncSequence. The trajectory:

- **2019:** Combine ships
- **2021:** Swift 5.5 introduces async/await, actors, AsyncSequence
- **2022-2023:** WWDC goes async/await heavy. Combine sessions stop.
- **2023:** Swift 5.9 introduces `@Observable` — built without Combine

Apple's playbook: Ship framework solution (Combine), ship language solution (async/await), let framework become "still works, not deprecated, not evolving."


## What Does @Observable Use?

**[U]** "so what does the observable macro use behind the scenes?"

**[C]** The Observation framework — completely separate from Combine.

Key difference is **pull vs push**:

**Combine (push):** Publisher emits changes, subscriber receives all, filters what it needs.

**Observation (pull):** Framework tracks which properties you READ. Only notifies when those specific properties change.

```swift
withObservationTracking {
    print(viewModel.count)  // Framework notes: "they read .count"
} onChange: {
    // Called when .count changes, NOT when .name changes
}
```

More efficient — no unnecessary updates. If your view only reads `.count`, changes to `.name` don't trigger re-render.


## Decision: Add to ADR

**[U]** "yeah, sounds like we should add to the ADR that we're probably gonna go with asyncstream long term then"

**[C]** Added "Async Primitive Strategy" section to ADR-001:

**Long-term direction:** AsyncStream/AsyncSequence

**Migration path:**
1. Now: async/await for batch (already done)
2. When streaming needed: Bridge SDK's `AnyPublisher` to `AsyncThrowingStream` at infrastructure boundary
3. If SDK is updated: Migrate streaming API directly (local fork allows this)

**Boundaries:**
- `@Observable` / `@Published` at SwiftUI boundary
- AsyncStream for everything below
- Bridge once, at the ViewModel layer


---

## Synthesis

___

[S] **Async Primitive Layering**

The architecture now has explicit guidance on async primitives:

1. **Accept reality at infrastructure** — SDK gives Combine for streaming, don't fight it
2. **Bridge once at ViewModel** — This is already the bridge layer between SwiftUI and actors
3. **Pure async below** — Agent layer and infrastructure use async/await and AsyncStream
4. **Follow Apple's trajectory** — Language features over framework features

This resolves what could have been ongoing friction about "should this be a publisher or a stream?" The answer is now documented: stream below, publisher at UI boundary, bridge in between.

The key insight: speculating about SDK behavior was wrong. Checking the actual code took 30 seconds and gave a definitive answer. "Likely" should have been "let me check."
