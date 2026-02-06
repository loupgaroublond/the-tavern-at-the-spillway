# Building a Custom SwiftUI Persistence Layer

## A Complete Technical Guide

*For developers building SwiftData-level integration from scratch*

---

# Part I: Foundation Concepts

## Chapter 1: Integration Requirements Overview

Building a persistence layer that feels native to SwiftUI requires implementing eleven interconnected systems. This guide covers each in depth.

### The Integration Surface

| Area | What It Provides | Key Challenge |
|------|------------------|---------------|
| Observation System | Automatic UI updates when data changes | Understanding @Observable macro internals |
| DynamicProperty | Query results that trigger view updates | Undocumented protocol requirements |
| Environment Injection | Database/context access throughout view hierarchy | Proper lifetime management |
| Context Pattern | Change staging before persistence | Implementing dirty tracking |
| Model Identity | Stable object identity for SwiftUI diffing | Handling refetches without losing view state |
| Lazy Loading | Deferred object materialization | Faulting without Core Data |
| Relationships | Bidirectional object graphs | Inverse maintenance, cascade rules |
| Schema/Migrations | Evolving data models over time | Safe upgrade paths |
| Concurrency | Background I/O without data races | Actor isolation, MainActor coordination |
| Undo Integration | System-level undo/redo support | Registering every mutation |
| Query Observation | Live-updating filtered/sorted results | Efficient change detection |

---

# Part II: The Observation System

## Chapter 2: How @Observable Works

The `@Observable` macro (iOS 17+) transforms your classes to enable property-level change tracking.

### Macro Expansion

When you write:

```swift
@Observable
class Task {
    var title: String = ""
    var isComplete: Bool = false
}
```

The macro generates:

```swift
class Task: Observable {
    @ObservationTracked
    var title: String = "" {
        get {
            access(keyPath: \.title)
            return _title
        }
        set {
            withMutation(keyPath: \.title) {
                _title = newValue
            }
        }
    }
    
    @ObservationIgnored private var _title: String = ""
    
    @ObservationIgnored
    private let _$observationRegistrar = ObservationRegistrar()
    
    internal nonisolated func access<Member>(keyPath: KeyPath<Task, Member>) {
        _$observationRegistrar.access(self, keyPath: keyPath)
    }
    
    internal nonisolated func withMutation<Member, T>(
        keyPath: KeyPath<Task, Member>,
        _ mutation: () throws -> T
    ) rethrows -> T {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
    }
}
```

### How SwiftUI Uses It

SwiftUI wraps every `body` evaluation in `withObservationTracking`:

```swift
// Conceptually what SwiftUI does:
let (content, trackedPaths) = withObservationTracking {
    viewInstance.body  // Your body code runs here
} onChange: {
    scheduleViewUpdate()  // Called when ANY tracked property changes
}
```

Properties accessed during `body` evaluation are recorded. When any tracked property changes, the view is scheduled for re-render. This is **property-level** tracking—changing `task.title` only affects views that read `title`, not views that only read `isComplete`.

### Performance Characteristics

| Metric | @Observable | @Published (Combine) |
|--------|-------------|---------------------|
| Read overhead | 2-5ns | 20-50ns |
| Write overhead (no observers) | 5-10ns | 50-200ns |
| Memory per object | 64-112 bytes | Heavier (publishers) |

The overhead comes from thread-local storage checks on every property access. The fast path (no active tracking context) is highly optimized—just a nil check on thread-local storage.

### Practical Mitigations

**For non-UI properties:**
```swift
@Observable
class Task {
    var title: String = ""
    
    @ObservationIgnored
    var cachedHash: Int?  // No observation overhead
}
```

**For batch reads:**
```swift
// Don't scan many objects inside view body
func countComplete() -> Int {
    tasks.count { $0.isComplete }  // Outside tracking context
}

// Store result in single observed property
var completedCount: Int
```

**Hybrid architecture:**
```swift
// Storage layer: plain structs, fast
struct TaskRecord: Codable {
    var id: UUID
    var title: String
}

// View layer: observable wrappers, reactive
@Observable
class TaskViewModel {
    private var record: TaskRecord
    var title: String {
        get { record.title }
        set { record.title = newValue }
    }
}
```

---

## Chapter 3: Edge Synchronization

When your storage layer uses plain structs but views use `@Observable` wrappers, you face an **edge synchronization** problem: wrappers can hold stale snapshots.

### The Challenge

```
Storage: [TaskRecord(id: 1, title: "Old")]
                    ↓ creates
ViewModel: TaskViewModel wrapping snapshot
                    ↓
                 View renders "Old"
                    ↓
Storage changes: [TaskRecord(id: 1, title: "New")]
                    ↓
ViewModel still shows "Old"  ← STALE
```

### Recommended Pattern

The context holds canonical data; view models are lightweight wrappers created on-demand:

```swift
class PersistenceContext {
    // Canonical storage
    private var records: [UUID: TaskRecord] = [:]
    
    // View model cache (weak or evictable)
    private var viewModels: [UUID: WeakRef<TaskViewModel>] = [:]
    
    func viewModel(for id: UUID) -> TaskViewModel {
        if let existing = viewModels[id]?.value {
            return existing
        }
        let vm = TaskViewModel(record: records[id]!, context: self)
        viewModels[id] = WeakRef(vm)
        return vm
    }
    
    func didUpdate(_ id: UUID) {
        // Push changes to any live view model
        viewModels[id]?.value?.reload(from: records[id]!)
    }
}
```

This gives you fast bulk operations on storage while keeping UI reactivity clean.

---

# Part III: SwiftUI Integration

## Chapter 4: DynamicProperty and @Query Implementation

`DynamicProperty` is the protocol that makes property wrappers like `@State`, `@Query`, and `@Environment` work with SwiftUI's update cycle.

### Critical Constraints

**DynamicProperty MUST be a struct, never a class.** As Donny Wals documented: "Defining a DynamicProperty property wrapper as a class produces very inconsistent results."

The proven pattern across all successful implementations:

```swift
@propertyWrapper
struct Query<T>: DynamicProperty {
    // StateObject provides the bridge to SwiftUI's update system
    @StateObject private var core = QueryCore<T>()
    
    var wrappedValue: [T] {
        core.results
    }
    
    // Called by SwiftUI before each body evaluation
    mutating func update() {
        // Load or refresh if needed
        // WARNING: Don't synchronously modify @State here
    }
    
    final class QueryCore<T>: ObservableObject {
        @Published var results: [T] = []
        private var cancellable: AnyCancellable?
        
        func observe(descriptor: QueryDescriptor<T>, context: PersistenceContext) {
            cancellable = context.publisher(for: descriptor)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newResults in
                    self?.results = newResults
                }
        }
    }
}
```

### The Three-Layer Architecture

1. **QueryDescriptor** — Pure value describing what to fetch
2. **QueryCore** — Observable class managing lifecycle and results
3. **Query** — Struct wrapper conforming to DynamicProperty

### Smart Change Invalidation

Don't refetch on every database change—only when relevant data changed:

```swift
func shouldInvalidate(for changes: DatabaseChanges) -> Bool {
    // Check if any changed table is in our query
    guard changes.modifiedTables.contains(descriptor.tableName) else {
        return false
    }
    
    // For updates, check if changed rows match our predicate
    for updatedID in changes.updatedIDs {
        if currentResultIDs.contains(updatedID) {
            return true
        }
    }
    
    // For inserts, check if new rows would match predicate
    for insertedRow in changes.insertedRows {
        if descriptor.predicate.evaluate(insertedRow) {
            return true
        }
    }
    
    return false
}
```

### MVVM Incompatibility Warning

**@Query-style wrappers fundamentally conflict with MVVM.** GRDB's maintainer describes @Query as an "anti-MVVM tool" because it embeds database access directly in views.

Attempting to use DynamicProperty inside an ObservableObject view model produces:
```
"Accessing StateObject's object without being installed on a View"
```

DynamicProperty requires installation on a View to function. If you need view models, use Point-Free's swift-sharing approach or GRDB's ValueObservation with Combine publishers.

---

## Chapter 5: Environment Injection

Database contexts should flow through SwiftUI's environment:

```swift
// Define the environment key
struct PersistenceContextKey: EnvironmentKey {
    static let defaultValue: PersistenceContext? = nil
}

extension EnvironmentValues {
    var persistenceContext: PersistenceContext? {
        get { self[PersistenceContextKey.self] }
        set { self[PersistenceContextKey.self] = newValue }
    }
}

// Inject at app root
@main
struct MyApp: App {
    let context = PersistenceContext()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.persistenceContext, context)
        }
    }
}

// Access in views
struct TaskList: View {
    @Environment(\.persistenceContext) var context
    
    var body: some View {
        // context is available here
    }
}
```

---

# Part IV: Concurrency

## Chapter 6: Swift Async/Await Threading Model

Swift's async/await uses a fundamentally different threading model than GCD.

### The Cooperative Thread Pool

The runtime maintains a **fixed-size pool of threads**—one per CPU core. On a 6-core iPhone, you get exactly 6 threads for async work.

```
Traditional GCD:
100 blocking tasks → 100 threads → thread explosion

Swift Concurrency:
100 tasks → 6 threads → tasks suspend at await, share threads
```

### How Suspension Works

When you write `await`, the task:

1. Packages its state as a **continuation**
2. **Releases its thread** immediately
3. The thread picks up other work
4. When the awaited operation completes, some thread resumes the continuation

This is cooperative multitasking—tasks yield voluntarily at `await` points.

### The Forward Progress Contract

The runtime assumes threads always make forward progress. **Never block threads** with:
- `Thread.sleep()`
- `DispatchSemaphore.wait()`
- Synchronous file I/O
- Any blocking syscall

These violate the contract and can cause deadlocks.

### Actor Hopping

Actors share the cooperative pool. Switching between actors ("hopping") is often just a function call, not a context switch—unless you're hopping to/from MainActor, which is pinned to the main thread.

**Minimize MainActor hops:**
```swift
// Bad: 2000 context switches for 1000 items
@MainActor
func updateUI() async {
    for item in items {
        let result = await backgroundActor.process(item)
        label.text = result
    }
}

// Good: 2 context switches total
@MainActor
func updateUI() async {
    let results = await backgroundActor.processAll(items)
    for (i, result) in results.enumerated() {
        labels[i].text = result
    }
}
```

### When You Need Custom Thread Management

**Thread affinity requirements:**
```swift
// Core Audio, OpenGL, thread-local storage
public final class ThreadExecutor: SerialExecutor {
    private var thread: Thread!
    
    public func enqueue(_ job: consuming ExecutorJob) {
        // Schedule on dedicated thread
    }
}

actor AudioProcessor {
    private nonisolated let executor = ThreadExecutor(name: "CoreAudio")
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }
}
```

**Dedicated compute pools:**
```swift
let computePool = ComputePoolExecutor(threadCount: 4)

await withTaskExecutorPreference(computePool) {
    await parallelMatrixMultiply(a, b)
}
```

For most apps, the default pool works fine. Custom executors are escape hatches for specialized scenarios.

---

## Chapter 7: Persistence Context Concurrency

### The Lost Update Problem

Multiple contexts reading the same data, making different changes, both saving—last save overwrites first.

**Solution for multi-agent apps:**
- Main context on @MainActor for UI
- Background contexts for heavy work
- Optimistic concurrency with version numbers
- Custom merge logic per data type

```swift
@MainActor
class MainContext: PersistenceContext {
    // UI reads and writes here
}

actor BackgroundContext: PersistenceContext {
    func processLargeImport(_ data: [Record]) async {
        // Heavy work here, notify main context when done
    }
}
```

### Merge Strategies by Data Type

| Data Type | Strategy |
|-----------|----------|
| Conversation histories | Append-only union |
| Agent configs | Last-write-wins |
| Tool results | Timestamp ordering |
| User preferences | Last-write-wins |

---

# Part V: Data Consistency

## Chapter 8: Transaction-Based Observation (GRDB's Approach)

GRDB's author identified a fundamental problem with property-level observation: **invariant violations**.

### The Problem

```swift
struct HallOfFame {
    var totalPlayerCount: Int
    var bestPlayers: [Player]  // Always <= totalPlayerCount
}
```

If you observe these properties separately and combine them:

```swift
let countPublisher = ValueObservation.tracking(Player.fetchCount)
let bestPublisher = ValueObservation.tracking(Player.limit(10).fetchAll)
let combined = countPublisher.combineLatest(bestPublisher)
```

Race condition: `bestPublisher` might fire before `countPublisher`, showing "5 players total, top 8" for a brief moment.

### The Solution

Observe entire transactions, not individual values:

```swift
let observation = ValueObservation.tracking { db -> HallOfFame in
    let count = try Player.fetchCount(db)
    let best = try Player.limit(10).fetchAll(db)
    return HallOfFame(totalPlayerCount: count, bestPlayers: best)
}
```

All values in a single notification come from the same transaction snapshot. You can never see partially-updated data.

### DatabaseRegion: The Observation Unit

GRDB tracks which tables/columns/rows your query touched. When a transaction commits, it checks: "Did this modify anything in that region?" Only then does it re-execute your query.

### Implications for Your Design

**Path 1: Accept eventual consistency** (simpler)
- Use @Observable on individual objects
- Accept momentary intermediate states
- Fine for most apps

**Path 2: Transaction-based observation** (GRDB's approach)
- Observe query results, not individual objects
- Re-fetch entire query on relevant changes
- Required when data has cross-field invariants

---

# Part VI: SwiftUI Performance

## Chapter 9: ObservableObject Performance (Alexey Naumov's Discovery)

### The Problem

In Redux-style apps with centralized state, performance degrades proportionally to **subscribed views**, not changed views.

> "We can have thousands of views with just one subscribed—updates are instant. But a few hundred subscribed views causes significant performance degradation."

### Why EquatableView Fails

The intuitive fix—wrap views in `EquatableView` with custom comparison—fails catastrophically with ObservableObject.

```swift
static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.appState.value == rhs.appState.value
}
```

Both `lhs` and `rhs` are different struct instances, but they hold references to the **same** `AppState` object. You're comparing an object to itself. It always returns `true`. The view freezes forever.

### The Working Solution

Abandon ObservableObject for centralized state. Use Combine publishers with explicit filtering:

```swift
struct ContentView: View {
    @State private var state = ViewState()
    @Environment(\.appState) private var appState: AnyPublisher<AppState, Never>
    
    var body: some View {
        Text("Value: \(state.value)")
            .onReceive(filteredState) { self.state = $0 }
    }
    
    private var filteredState: AnyPublisher<ViewState, Never> {
        appState
            .map { ViewState(value: $0.relevantField) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
```

Each view maps global state to a local struct containing only needed fields, then uses `.removeDuplicates()`.

### Relevance to Persistence

1. **Don't make your entire data store an ObservableObject** that views subscribe to
2. **With @Observable (iOS 17+)**, property-level tracking helps, but EquatableView still fails with reference types
3. **For aggregate queries**, use Combine publishers or GRDB's ValueObservation

---

## Chapter 10: View Update Timing Issues

### Content Closures Don't Form Dependencies

```swift
List(items) { item in
    Text(item.name)  // Does NOT form dependency on item!
}
```

SwiftUI forms dependencies when `body` directly reads observable properties, but NOT when content closures do. This is a common source of "view not updating" bugs.

### Table vs List Behavior

SwiftUI Table doesn't track @Observable changes while List does—documented as confusing behavior with no clear resolution.

### Large Dataset Performance

Never convert NSArray to Swift Array when fetching from Core Data. Bridging forces loading all objects into memory immediately. Maintain lazy NSArray access through wrapper types.

---

# Part VII: Automation

## Chapter 11: Reducing Boilerplate with Macros

### The Tedium Inventory

**Tier 1: Per-Model Boilerplate**
- Undo registration on every property
- Codable conformance for complex types
- Inverse relationship maintenance
- Validation logic

**Tier 2: Per-Schema-Version**
- Migration code for each version transition

**Tier 3: One-Time but Fiddly**
- Change tracking infrastructure
- Cascade delete logic
- Conflict resolution

### Recommended Macros

Build 2-3 custom macros:

**@Persistable** — Class-level macro generating:
- ObservationRegistrar
- Codable conformance
- Registration with context

**@Persisted** — Property-level macro generating:
- Backing storage
- Change tracking
- Undo registration

**@Relationship(inverse:)** — Bidirectional maintenance

### Macro Implementation Skeleton

```swift
@attached(accessor)
@attached(peer, names: prefixed(`_`))
public macro Persisted() = #externalMacro(
    module: "PersistenceMacros",
    type: "PersistedMacro"
)

// Transforms:
@Persisted var title: String = ""

// Into:
private var _title: String = ""
var title: String {
    get {
        access(keyPath: \.title)
        return _title
    }
    set {
        let oldValue = _title
        withMutation(keyPath: \.title) {
            _title = newValue
        }
        persistenceContext?.willChange(self, property: "title", from: oldValue, to: newValue)
    }
}
```

### Working with Claude Code

Macro authoring works well with Claude Code for:
- Generating implementations from clear specs
- Following patterns from existing macros
- Repetitive transformation logic

Harder:
- Debugging expansion failures (cryptic errors)
- Complex SwiftSyntax traversals

Recommended workflow: Spec clearly with input/output examples, start simple, expect 2-3 iteration rounds.

---

# Part VIII: Library Approaches

## Chapter 12: What Others Have Built

### GRDB + GRDBQuery

Most mature SwiftUI integration outside Apple. Uses ValueObservation with Combine publishers, environment-based database injection. Explicitly anti-MVVM.

### Point-Free swift-sharing

Most ambitious alternative. @FetchAll and @FetchOne work in SwiftUI views, @Observable models, AND UIKit controllers by not relying on DynamicProperty for observation.

### Boutique

Uses @Observable directly rather than implementing DynamicProperty. All core types bound to @MainActor.

### Realm SwiftUI

@ObservedResults and @ObservedRealmObject implement DynamicProperty with Realm's native notification system. Same MVVM incompatibility issues.

### SwiftData

Avoid @Query for main-thread-blocking operations. Move to view models with FetchDescriptor and explicit ModelContext management.

---

# Part IX: Summary

## Key Decisions for Your Framework

1. **Use @Observable from Apple** — Don't reinvent observation
2. **Implement DynamicProperty as struct** with internal @StateObject
3. **Transaction-based observation** for data with invariants
4. **Property-level observation** for simple configuration
5. **MainActor for UI context**, background actors for heavy work
6. **Minimize MainActor hops** by batching
7. **Custom macros** for repetitive per-model boilerplate
8. **Default cooperative pool** unless you have thread-affinity requirements

## What Succeeds

- Structs for DynamicProperty, never classes
- @StateObject internally for triggering updates
- Environment injection for database connections
- Setting relationships after context insertion
- autoreleasepool for large dataset processing

## What Fails

- Classes as DynamicProperty implementations
- SwiftData's @Query for heavy operations
- EquatableView with reference-type state
- Storing large binary data in models
- Eagerly loading all fetch results

---

*Document generated from extended technical research session, January 2026*
