import NanoRedux
import Observation
import Testing

@MainActor
@Test func concatRunsEffectsSerially() async throws {
    struct TestState: Observable {
        var events: [String] = []
    }
    enum TestAction: Sendable {
        case start
        case step1
        case step2
    }

    struct TestReducer: Reducer {
        func reduce(
            into state: inout TestState,
            action: TestAction,
        ) -> Effect<TestAction> {
            switch action {
            case .start:
                return .concat {
                    Effect.run { .step1 }
                    Effect.run { .step2 }
                }
            case .step1:
                state.events.append("step1")
            case .step2:
                state.events.append("step2")
            }
            return .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
    )

    store.send(.start)

    try await Task.sleep(for: .milliseconds(20))

    #expect(store.state.events == ["step1", "step2"])
}

@MainActor
@Test func mergeRunsEffectsConcurrently() async throws {
    struct TestState: Observable {
        var events: [String] = []
    }
    enum TestAction: Sendable {
        case start
        case fast
        case slow
    }

    struct TestReducer: Reducer {
        func reduce(
            into state: inout TestState,
            action: TestAction,
        ) -> Effect<TestAction> {
            switch action {
            case .start:
                return .merge {
                    Effect.run {
                        try? await Task.sleep(for: .milliseconds(10))
                        return .slow
                    }
                    Effect.run { .fast }
                }
            case .fast:
                state.events.append("fast")
            case .slow:
                state.events.append("slow")
            }
            return .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
    )

    store.send(.start)

    try await Task.sleep(for: .milliseconds(40))

    #expect(Set(store.state.events) == ["fast", "slow"])
    #expect(store.state.events.count == 2)
}

@MainActor
@Test func debounceExecutesOnlyLatestEffect() async throws {
    struct TestState: Observable {
        var values: [String] = []
    }
    enum TestAction: Sendable {
        case input(String)
        case debounced(String)
    }

    struct TestReducer: Reducer {
        func reduce(
            into state: inout TestState,
            action: TestAction,
        ) -> Effect<TestAction> {
            switch action {
            case let .input(value):
                return .debounce(for: .milliseconds(40), key: "search") {
                    Effect.run { .debounced(value) }
                }
            case let .debounced(value):
                state.values.append(value)
                return .none
            }
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
    )

    store.send(.input("a"))
    try await Task.sleep(for: .milliseconds(10))
    store.send(.input("ab"))
    try await Task.sleep(for: .milliseconds(10))
    store.send(.input("abc"))

    try await Task.sleep(for: .milliseconds(80))

    #expect(store.state.values == ["abc"])
}

@MainActor
@Test func throttleExecutesLeadingEffectOnly() async throws {
    struct TestState: Observable {
        var fireCount: Int = 0
    }
    enum TestAction: Sendable {
        case tap
        case fired
    }

    struct TestReducer: Reducer {
        func reduce(
            into state: inout TestState,
            action: TestAction,
        ) -> Effect<TestAction> {
            switch action {
            case .tap:
                return .throttle(for: .milliseconds(50), key: "tap") {
                    Effect.run { .fired }
                }
            case .fired:
                state.fireCount += 1
                return .none
            }
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
    )

    store.send(.tap)
    store.send(.tap)
    store.send(.tap)

    try await Task.sleep(for: .milliseconds(20))

    #expect(store.state.fireCount == 1)

    try await Task.sleep(for: .milliseconds(50))
    store.send(.tap)
    try await Task.sleep(for: .milliseconds(20))

    #expect(store.state.fireCount == 2)
}
