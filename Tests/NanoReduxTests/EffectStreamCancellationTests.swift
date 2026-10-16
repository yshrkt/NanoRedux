@testable import NanoRedux
import Synchronization
import Testing

private final class StreamSubscriptions: Sendable {
    private struct State {
        var started = 0
        var cancelled = 0
        var continuations: [AsyncStream<Int>.Continuation] = []
    }

    private let state = Mutex(State())

    func observe() -> AsyncStream<Int> {
        AsyncStream { continuation in
            continuation.onTermination = { [self] termination in
                if case .cancelled = termination {
                    state.withLock { $0.cancelled += 1 }
                }
            }
            state.withLock {
                $0.continuations.append(continuation)
                $0.started += 1
            }
        }
    }

    func finishAll() {
        let continuations = state.withLock { $0.continuations }
        for continuation in continuations {
            continuation.finish()
        }
    }

    func waitFor(started: Int, cancelled: Int) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            if state.withLock({ $0.started == started && $0.cancelled == cancelled }) {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        let counts = state.withLock { ($0.started, $0.cancelled) }
        #expect(counts.0 == started)
        #expect(counts.1 == cancelled)
        try #require(counts.0 == started && counts.1 == cancelled)
    }
}

@MainActor
@Test(arguments: [0, 1, 2])
func replaceableStreamCancelsUnderlyingSubscription(mapCount: Int) async throws {
    let subscriptions = StreamSubscriptions()
    let runtime = EffectRuntime<Int>()
    defer {
        runtime.cancelAll()
        subscriptions.finishAll()
    }

    var effect = Effect<Int>.stream(lifetime: .replaceable("purchases")) {
        subscriptions.observe()
    }
    for _ in 0 ..< mapCount {
        effect = effect.map { $0 + 1 }
    }

    runtime.run(effect) { _ in }
    try await subscriptions.waitFor(started: 1, cancelled: 0)

    runtime.run(effect) { _ in }
    try await subscriptions.waitFor(started: 2, cancelled: 1)

    runtime.cancelAll()
    try await subscriptions.waitFor(started: 2, cancelled: 2)
}

@MainActor
@Test(arguments: [false, true])
func cancellingExecuteForTestingCancelsUnderlyingSubscription(mapped: Bool) async throws {
    let subscriptions = StreamSubscriptions()
    var effect = Effect<Int>.stream { subscriptions.observe() }
    if mapped {
        effect = effect.map { $0 + 1 }
    }
    let task = Task { await effect.executeForTesting() }
    defer {
        task.cancel()
        subscriptions.finishAll()
    }

    try await subscriptions.waitFor(started: 1, cancelled: 0)
    task.cancel()
    try await subscriptions.waitFor(started: 1, cancelled: 1)
    let result = await task.value
    #expect(result == nil)
}

@Test func mappedStreamCompletesNormally() async {
    let effect = Effect<Int>.stream {
        AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.yield(2)
            continuation.finish()
        }
    }.map { $0 * 10 }

    let result = await effect.executeForTesting()
    #expect(result == 20)
}
