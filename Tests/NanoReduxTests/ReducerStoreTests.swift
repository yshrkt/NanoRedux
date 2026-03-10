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
    struct TestReducer: Reducer {
        func reduce(
            into _: inout TestState,
            action _: TestAction,
        ) -> Effect<TestAction> {
            .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(),
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
    struct TestReducer: InjectableReducer {
        struct Dependencies {
            let step: Int
        }

        let dependencies: Dependencies

        func reduce(
            into state: inout TestState,
            action: TestAction,
        ) -> Effect<TestAction> {
            if case .increment = action {
                state.count += dependencies.step
            }
            return .none
        }
    }

    let store = Store<TestState, TestAction>.reducer(
        initialState: TestState(),
        reducer: TestReducer(dependencies: .init(step: 1)),
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
    struct TestReducer: Reducer {
        func reduce(
            into state: inout TestState,
            action: TestAction,
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
    )

    store.send(.increment)
    store.send(.increment)
    store.send(.increment)

    try await Task.sleep(for: .milliseconds(20))

    #expect(store.state.count == 3)
}
