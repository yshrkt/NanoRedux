import NanoRedux
import Observation
import Synchronization
import Testing

private enum ObservationFeature {
    @Observable
    final class State {
        var count: Int
        var unrelatedCount = 0
        var child: ChildState

        init(count: Int = 0) {
            self.count = count
            child = ChildState(count: count)
        }
    }

    @Observable
    final class ChildState {
        var count: Int

        init(count: Int) {
            self.count = count
        }
    }

    enum Action: Sendable {
        case replace(Int)
        case incrementChild
        case incrementUnrelated
    }

    struct Reducer: NanoRedux.Reducer {
        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case let .replace(count):
                state = State(count: count)
            case .incrementChild:
                state.child.count += 1
            case .incrementUnrelated:
                state.unrelatedCount += 1
            }
            return .none
        }
    }
}

@MainActor
private func waitForState(_ condition: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while !condition(), clock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
}

@MainActor
@Test(arguments: [false, true])
func replacingStateNotifiesObservers(readsProperty: Bool) async throws {
    let original = ObservationFeature.State()
    let store = Store.reducer(
        initialState: original,
        reducer: ObservationFeature.Reducer(),
    )
    let changes = Mutex(0)
    withObservationTracking {
        if readsProperty {
            _ = store.state.count
        } else {
            _ = store.state
        }
    } onChange: {
        changes.withLock { $0 += 1 }
    }

    store.send(.replace(1))
    try await waitForState { store.state.count == 1 }

    #expect(store.state !== original)
    #expect(original.count == 0)
    #expect(changes.withLock { $0 } == 1)
}

@MainActor
@Test(arguments: [1, 2])
func replacingParentStateNotifiesScopedObservers(scopeDepth: Int) async throws {
    let original = ObservationFeature.State()
    let parent = Store.reducer(
        initialState: original,
        reducer: ObservationFeature.Reducer(),
    )
    var child = parent.scope(state: { $0.child }, action: { $0 })
    for _ in 1 ..< scopeDepth {
        child = child.scope(state: { $0 }, action: { $0 })
    }

    let replacementChanges = Mutex(0)
    withObservationTracking {
        _ = child.state.count
    } onChange: {
        replacementChanges.withLock { $0 += 1 }
    }

    parent.send(.replace(1))
    try await waitForState { child.state.count == 1 }

    #expect(child.state === parent.state.child)
    #expect(child.state !== original.child)
    #expect(replacementChanges.withLock { $0 } == 1)

    // Re-register as SwiftUI would, then observe the new child rather than the old one.
    let mutationChanges = Mutex(0)
    withObservationTracking {
        _ = child.state.count
    } onChange: {
        mutationChanges.withLock { $0 += 1 }
    }
    original.child.count += 1
    #expect(mutationChanges.withLock { $0 } == 0)

    child.send(.incrementChild)
    try await waitForState { child.state.count == 2 }
    #expect(mutationChanges.withLock { $0 } == 1)
}

@MainActor
@Test func valueStateChangesNotifyObservers() async throws {
    struct ValueState: Observable {
        var count = 0
    }
    struct ValueReducer: Reducer {
        func reduce(into state: inout ValueState, action: Int) -> Effect<Int> {
            state = ValueState(count: action)
            return .none
        }
    }
    let store = Store.reducer(initialState: ValueState(), reducer: ValueReducer())
    let changes = Mutex(0)
    withObservationTracking {
        _ = store.state.count
    } onChange: {
        changes.withLock { $0 += 1 }
    }

    store.send(1)
    try await waitForState { store.state.count == 1 }
    #expect(changes.withLock { $0 } == 1)
}

@MainActor
@Test func unrelatedReferenceStateChangesDoNotNotifyObservers() async throws {
    let store = Store.reducer(
        initialState: ObservationFeature.State(),
        reducer: ObservationFeature.Reducer(),
    )
    let changes = Mutex(0)
    withObservationTracking {
        _ = store.state.count
    } onChange: {
        changes.withLock { $0 += 1 }
    }

    store.send(.incrementUnrelated)
    try await waitForState { store.state.unrelatedCount == 1 }
    #expect(changes.withLock { $0 } == 0)
}
