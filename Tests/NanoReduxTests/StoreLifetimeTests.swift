@testable import NanoRedux
import Observation
import Synchronization
import Testing

private struct LifetimeState: Observable {
    var receivedCount = 0
}

private enum LifetimeAction: Sendable {
    case start
    case received
}

private struct LifetimeReducer: Reducer {
    let effect: Effect<LifetimeAction>

    func reduce(
        into state: inout LifetimeState,
        action: LifetimeAction,
    ) -> Effect<LifetimeAction> {
        switch action {
        case .start:
            return effect
        case .received:
            state.receivedCount += 1
            return .none
        }
    }
}

@MainActor
private func waitUntil(_ condition: () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while !condition(), clock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
}

@MainActor
@Test func reducerStoreIsReleasedWhileWaitingForActions() async throws {
    var core: ReducerStore<LifetimeReducer>? = ReducerStore(
        initialState: LifetimeState(),
        reducer: LifetimeReducer(effect: .none),
    )
    let isReleased = { [weak core] in core == nil }

    core?.send(.received)
    try await waitUntil { core?.state.receivedCount == 1 }

    core = nil
    try await waitUntil(isReleased)
}

@MainActor
@Test(arguments: [EffectLifetime.storeBound, .replaceable("subscription")])
func releasingStoreCancelsManagedStream(lifetime: EffectLifetime) async throws {
    let (stream, continuation) = AsyncStream<LifetimeAction>.makeStream()
    let cancelled = Mutex(false)
    continuation.onTermination = { termination in
        if case .cancelled = termination {
            cancelled.withLock { $0 = true }
        }
    }
    defer { continuation.finish() }

    var store: Store<LifetimeState, LifetimeAction>? = .reducer(
        initialState: LifetimeState(),
        reducer: LifetimeReducer(effect: .stream(lifetime: lifetime) { stream }),
    )
    let isReleased = { [weak store] in store == nil }

    store?.send(.start)
    continuation.yield(.received)
    try await waitUntil { store?.state.receivedCount == 1 }

    store = nil
    try await waitUntil(isReleased)
    try await waitUntil { cancelled.withLock { $0 } }
}

@MainActor
@Test func releasingStoreCancelsStoreBoundRun() async throws {
    let started = Mutex(false)
    let cancelled = Mutex(false)
    var store: Store<LifetimeState, LifetimeAction>? = .reducer(
        initialState: LifetimeState(),
        reducer: LifetimeReducer(effect: .run {
            started.withLock { $0 = true }
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                cancelled.withLock { $0 = Task.isCancelled }
            }
            return nil
        }),
    )
    let isReleased = { [weak store] in store == nil }

    store?.send(.start)
    try await waitUntil { started.withLock { $0 } }

    store = nil
    try await waitUntil(isReleased)
    try await waitUntil { cancelled.withLock { $0 } }
}
