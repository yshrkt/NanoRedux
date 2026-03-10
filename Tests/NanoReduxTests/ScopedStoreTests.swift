import NanoRedux
import Observation
import Testing

@MainActor
@Test func scopedStoreInitialState() {
    struct ParentState: Observable {
        var value: String = "parent"
    }
    enum ParentAction: Sendable {
        case message(String)
    }
    struct LocalState: Observable {
        var value: String = "local"
    }
    enum LocalAction: Sendable {
        case message(String)
    }

    struct ParentReducer: Reducer {
        func reduce(
            into _: inout ParentState,
            action _: ParentAction,
        ) -> Effect<ParentAction> {
            .none
        }
    }

    let parentStore = Store<ParentState, ParentAction>.reducer(
        initialState: ParentState(),
        reducer: ParentReducer(),
    )

    let scopedStore = parentStore.scope(
        state: { $0 },
        action: { $0 },
    )

    #expect(scopedStore.state.value == "parent")
}

@MainActor
@Test func scopedStoreSendAction() async throws {
    struct ParentState: Observable {
        var counter: Int = 0
    }
    enum ParentAction: Sendable {
        case increment
    }

    struct ParentReducer: Reducer {
        func reduce(
            into state: inout ParentState,
            action: ParentAction,
        ) -> Effect<ParentAction> {
            if case .increment = action {
                state.counter += 1
            }
            return .none
        }
    }

    struct LocalState: Observable {
        var counter: Int = 0
    }
    enum LocalAction: Sendable {
        case increment
    }

    let parentStore = Store<ParentState, ParentAction>.reducer(
        initialState: ParentState(),
        reducer: ParentReducer(),
    )

    let scopedStore = parentStore.scope(
        state: { ParentState(counter: $0.counter) },
        action: { (_: LocalAction) in ParentAction.increment },
    )

    #expect(scopedStore.state.counter == 0)
    #expect(parentStore.state.counter == 0)

    scopedStore.send(.increment)

    try await Task.sleep(for: .milliseconds(10))

    #expect(scopedStore.state.counter == 1)
    #expect(parentStore.state.counter == 1)
}
