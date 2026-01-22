# Why ChatViewModel Exists

The `ChatViewModel` exists for several architectural reasons:


## 1. SwiftUI's MVVM Pattern

SwiftUI is designed around reactive data binding. The ViewModel is `@ObservableObject`, and Views observe it via `@ObservedObject`. When any `@Published` property changes, SwiftUI automatically re-renders affected views:

```swift
@Published public private(set) var messages: [ChatMessage] = []
@Published public private(set) var isCogitating: Bool = false
@Published public var inputText: String = ""
```


## 2. Separation of Concerns

The ViewModel handles all the **logic**:

- Managing the message history
- Sending messages to the agent
- Handling errors and mapping them to user-friendly messages
- Managing UI state (cogitation verbs, loading state)

The View (`ChatView.swift`) just **renders** this state — it doesn't know how messages work, just that there's an array to display.


## 3. Agent Abstraction via `AnyAgent`

The ViewModel wraps any agent through `AnyAgent`:

```swift
private let agent: AnyAgent
```

This means `ChatView` doesn't care whether it's talking to Jake, a MortalAgent, or any future agent type. The ViewModel provides a uniform interface. Without this, the View would need to know about every agent type.


## 4. MainActor Isolation

The ViewModel is `@MainActor`, guaranteeing all state updates happen on the main thread. This is critical for SwiftUI — updating `@Published` properties from background threads causes crashes. The ViewModel is the boundary where async agent work gets marshaled back to the UI thread.


## 5. Testability

You can test chat logic without SwiftUI:

```swift
let viewModel = ChatViewModel(jake: mockJake)
await viewModel.sendMessage()
XCTAssertEqual(viewModel.messages.count, 2)
```


## Alternative: Why Not Just @State in the View?

You *could* put messages, cogitating, etc. directly in the View with `@State`. But then:

- The View mixes presentation with business logic
- You can't share chat state across multiple views
- Testing requires instantiating SwiftUI views
- Tighter coupling to specific agent types

The ViewModel is the bridge between the domain layer (agents, messages) and the presentation layer (SwiftUI views).
