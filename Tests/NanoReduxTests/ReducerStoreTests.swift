import NanoRedux
import Observation
import Testing

@MainActor
@Test func reducerStoreInitialState() {
    struct TestState: Observable {
        var count: Int = 5
    }
    enum TestAction: Sendable {
        case increment
    }
    struct TestDependencies {}

    struct TestReducer: Reducer {
        func callAsFunction(
            into _: inout TestState,
            action _: TestAction,
            dependencies _: TestDependencies,
        ) -> Effect<TestAction> {
            .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
        dependencies: TestDependencies(),
    )

    #expect(store.state.count == 5)
}

@MainActor
@Test func reducerStoreSendAction() async throws {
    struct TestState: Observable {
        var count: Int = 0
    }
    enum TestAction: Sendable {
        case increment
    }
    struct TestDependencies {}

    struct TestReducer: Reducer {
        func callAsFunction(
            into state: inout TestState,
            action: TestAction,
            dependencies _: TestDependencies,
        ) -> Effect<TestAction> {
            if case .increment = action {
                state.count += 1
            }
            return .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
        dependencies: TestDependencies(),
    )

    store.send(.increment)

    try await Task.sleep(for: .milliseconds(10))

    #expect(store.state.count == 1)
}

@MainActor
@Test func reducerStoreMultipleActions() async throws {
    struct TestState: Observable {
        var count: Int = 0
    }
    enum TestAction: Sendable {
        case increment
    }
    struct TestDependencies {}

    struct TestReducer: Reducer {
        func callAsFunction(
            into state: inout TestState,
            action: TestAction,
            dependencies _: TestDependencies,
        ) -> Effect<TestAction> {
            if case .increment = action {
                state.count += 1
            }
            return .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
        dependencies: TestDependencies(),
    )

    store.send(.increment)
    store.send(.increment)
    store.send(.increment)

    try await Task.sleep(for: .milliseconds(20))

    #expect(store.state.count == 3)
}
