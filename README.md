# NanoRedux

A lightweight, unidirectional data flow library for Swift, inspired by Redux. Built for SwiftUI with full Swift 6 concurrency support and Observation framework integration.

## Requirements

- Swift 6.2+
- iOS 18+ / macOS 15+ / visionOS 2+ / watchOS 11+ / macCatalyst 18+

## Installation

### Swift Package Manager

Add NanoRedux to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yshrkt/NanoRedux.git", from: "0.1.0")
]
```

Or add it via Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version and add to your target

## Core Concepts

### Store

The `Store` holds your app's state and handles action dispatching. It's `@Observable` and works seamlessly with SwiftUI.

Create a store with a reducer:

```swift
let store = Store.reducer(
    initialState: MyFeature.State(),
    reducer: MyFeature.Reducer(),
    dependencies: MyFeature.Dependencies()
)
```

#### Scope

Scoping allows you to derive child stores that focus on specific parts of your state, perfect for composing features.

```swift
let childStore = parentStore.scope(
    state: { $0.childState },
    action: { ChildAction.child($0) }
)
```

### Reducer

A `Reducer` defines how your app's state changes in response to actions. It's a pure function that takes the current state, an action, and dependencies, then returns a new state and optionally an effect.

```swift
public protocol Reducer {
    associatedtype State: Observable
    associatedtype Action: Sendable
    associatedtype Dependencies

    func callAsFunction(
        into state: inout State,
        action: Action,
        dependencies: Dependencies,
    ) -> Effect<Action>
}
```

### Effect

Effects handle side effects like network requests, timers, or any asynchronous operations. They can return actions to feed back into the store.

```swift
public struct Effect<Action: Sendable> {
    public let lifetime: EffectLifetime
}
```

**Effect Lifetimes:**

| Lifetime | Description |
|----------|-------------|
| `.storeBound` | Automatically cancelled when the store is deinitialized (default) |
| `.replaceable(key:)` | Replaces any in-flight effect with the same key |
| `.detached` | Continues independently of the store lifecycle |

Example:

```swift
// Simple async effect
Effect.run {
    let data = try await apiClient.fetchData()
    return .dataLoaded(data)
}

// Replaceable effect (useful for debouncing/refreshing)
Effect.run(lifetime: .replaceable("fetch")) {
    let result = try await apiClient.fetch()
    return .fetchComplete(result)
}
```

**Effect Composition:**

| Composition | Description |
|-------------|-------------|
| `.concat { ... }` | Runs child effects serially in declaration order |
| `.merge { ... }` | Runs child effects concurrently |
| `.throttle(for:key:) { ... }` | Runs the leading effect immediately and drops subsequent effects during the interval. The `key` defines which effects share the same throttle window |
| `.debounce(for:key:) { ... }` | Delays execution and keeps only the latest effect for the key. The `key` defines which pending effects replace one another |

Example:

```swift
// Serial execution
Effect.concat {
    Effect.run { .step1Finished }
    Effect.run { .step2Finished }
}

// Concurrent execution
Effect.merge {
    Effect.run { .profileLoaded(try await api.profile()) }
    Effect.run { .postsLoaded(try await api.posts()) }
}

// Leading-only throttle
Effect.throttle(for: .seconds(1), key: "save") {
    Effect.run { .saveRequested }
}

// Debounce latest input
Effect.debounce(for: .milliseconds(300), key: "search") {
    Effect.run { .searchRequested }
}
```

## Usage Example

### Basic Feature

```swift
import NanoRedux
import Observation

enum CounterFeature {
    @Observable
    final class State {
        var count = 0
    }

    enum Action: Sendable {
        case increment
        case decrement
        case reset
    }

    struct Reducer: NanoRedux.Reducer {
        typealias Dependencies = Void

        func callAsFunction(
            into state: inout State,
            action: Action,
            dependencies: Dependencies
        ) -> Effect<Action> {
            switch action {
            case .increment:
                state.count += 1
            case .decrement:
                state.count -= 1
            case .reset:
                state.count = 0
            }
            return .none
        }
    }
}
```

### Use in SwiftUI

```swift
struct CounterView: View {
    @State var store: Store<CounterFeature.State, CounterFeature.Action>

    var body: some View {
        VStack {
            Text("\(store.state.count)")
            HStack {
                Button("-") { store.send(.decrement) }
                Button("Reset") { store.send(.reset) }
                Button("+") { store.send(.increment) }
            }
        }
    }
}
```

### Composing Features

Combine multiple features into a single app-level store:

```swift
enum AppFeature {
    @Observable
    final class State {
        var todo: TodoFeature.State
        var settings: SettingsFeature.State
    }

    enum Action: Sendable {
        case todo(TodoFeature.Action)
        case settings(SettingsFeature.Action)
    }

    struct Dependencies: Sendable {
        let todo: TodoFeature.Dependencies
    }

    struct Reducer: NanoRedux.Reducer {
        private let todoReducer = TodoFeature.Reducer()
        private let settingsReducer = SettingsFeature.Reducer()

        func callAsFunction(
            into state: inout State,
            action: Action,
            dependencies: Dependencies
        ) -> Effect<Action> {
            switch action {
            case let .todo(childAction):
                return todoReducer(
                    into: &state.todo,
                    action: childAction,
                    dependencies: dependencies.todo
                ).map { Action.todo($0) }

            case let .settings(childAction):
                return settingsReducer(
                    into: &state.settings,
                    action: childAction,
                    dependencies: ()
                ).mapNone()
            }
        }
    }
}
```

For a complete working example with effects, see the [Example-iOS](./Example-iOS) project.

## License

NanoRedux is available under the MIT license. See the [LICENSE](./LICENSE) file for more info.
