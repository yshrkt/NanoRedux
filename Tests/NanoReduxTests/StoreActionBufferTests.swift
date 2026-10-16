import NanoRedux
import Observation
import Testing

private struct BufferedState: Observable {
    var values: [Int] = []
}

private enum BufferedAction: Sendable {
    case start
    case received(Int)
}

private struct BufferedReducer: Reducer {
    let values: [Int]

    func reduce(
        into state: inout BufferedState,
        action: BufferedAction,
    ) -> Effect<BufferedAction> {
        switch action {
        case .start:
            return .stream {
                AsyncStream<BufferedAction> { continuation in
                    for value in values {
                        continuation.yield(.received(value))
                    }
                    continuation.finish()
                }
            }
        case let .received(value):
            state.values.append(value)
            return .none
        }
    }
}

@MainActor
private func waitForLastAction(
    _ value: Int,
    in store: Store<BufferedState, BufferedAction>,
) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while store.state.values.last != value, clock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(store.state.values.last == value)
}

@MainActor
@Test(arguments: [257, 1000])
func storeProcessesBurstActionsWithoutDroppingOrReordering(actionCount: Int) async throws {
    let values = Array(0 ..< actionCount)
    let store = Store.reducer(
        initialState: BufferedState(),
        reducer: BufferedReducer(values: []),
    )

    // Do not suspend here: all actions must queue before the main-actor consumer can run.
    for value in values {
        store.send(.received(value))
    }
    try await waitForLastAction(actionCount - 1, in: store)

    try #require(store.state.values.count == actionCount)
    #expect(store.state.values == values)
}

@MainActor
@Test func storeProcessesStreamActionsWithoutDroppingOrReordering() async throws {
    let values = Array(0 ..< 1000)
    let store = Store.reducer(
        initialState: BufferedState(),
        reducer: BufferedReducer(values: values),
    )

    store.send(.start)
    try await waitForLastAction(999, in: store)

    try #require(store.state.values.count == values.count)
    #expect(store.state.values == values)
}
