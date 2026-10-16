import NanoRedux
import Synchronization
import Testing

// Ignores cancellation so tests can release in-flight work after cancelling executeForTesting().
private final class ExecutionGate: Sendable {
    private struct State {
        var started = 0
        var isOpen = false
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    var started: Int {
        state.withLock { $0.started }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock {
                $0.started += 1
                if $0.isOpen { return true }
                $0.waiters.append(continuation)
                return false
            }
            if resumeImmediately { continuation.resume() }
        }
    }

    func open() {
        let waiters = state.withLock {
            $0.isOpen = true
            let waiters = $0.waiters
            $0.waiters.removeAll()
            return waiters
        }
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private func waitUntil(_ condition: @Sendable () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while !condition(), clock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(condition())
}

@Test func cancellingExecuteForTestingSkipsRemainingConcatEffects() async throws {
    let gate = ExecutionGate()
    let secondStarted = Mutex(false)
    let effect = Effect<Int>.concat {
        Effect.run {
            await gate.wait()
            return nil
        }
        Effect.run {
            secondStarted.withLock { $0 = true }
            return 2
        }
    }
    let task = Task { await effect.executeForTesting() }
    defer {
        task.cancel()
        gate.open()
    }

    try await waitUntil { gate.started == 1 }
    task.cancel()
    gate.open()
    let result = await task.value

    #expect(!secondStarted.withLock { $0 })
    #expect(result == nil)
}

@Test(arguments: [false, true])
func cancellingExecuteForTestingDiscardsLateRunResult(mapped: Bool) async throws {
    let gate = ExecutionGate()
    var effect = Effect<Int>.run {
        await gate.wait()
        return 1
    }
    if mapped {
        effect = effect.map { $0 * 10 }
    }
    let task = Task { await effect.executeForTesting() }
    defer {
        task.cancel()
        gate.open()
    }

    try await waitUntil { gate.started == 1 }
    task.cancel()
    gate.open()
    let result = await task.value

    #expect(result == nil)
}

private enum CancelledOperation: CaseIterable, Sendable {
    case run, concat, merge, throttle, debounce
}

@Test(arguments: CancelledOperation.allCases)
private func alreadyCancelledExecuteForTestingDoesNotStartEffects(operation: CancelledOperation) async {
    let starts = Mutex(0)
    let leaf = Effect<Int>.run {
        starts.withLock { $0 += 1 }
        return 1
    }
    let effect: Effect<Int> = switch operation {
    case .run:
        leaf
    case .concat:
        leaf.concat(leaf)
    case .merge:
        leaf.merge(leaf)
    case .throttle:
        leaf.throttled(for: .seconds(1), key: "cancelled")
    case .debounce:
        leaf.debounced(for: .seconds(1), key: "cancelled")
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return await effect.executeForTesting()
    }
    let result = await task.value

    #expect(starts.withLock { $0 } == 0)
    #expect(result == nil)
}

@Test func cancellingExecuteForTestingSkipsEffectsAfterStream() async throws {
    let (stream, continuation) = AsyncStream<Int>.makeStream()
    let started = Mutex(false)
    let terminated = Mutex(false)
    let secondStarted = Mutex(false)
    continuation.onTermination = { termination in
        if case .cancelled = termination {
            terminated.withLock { $0 = true }
        }
    }
    let effect = Effect<Int>.stream {
        started.withLock { $0 = true }
        return stream
    }.concat(.run {
        secondStarted.withLock { $0 = true }
        return 2
    })
    let task = Task { await effect.executeForTesting() }
    defer {
        task.cancel()
        continuation.finish()
    }

    try await waitUntil { started.withLock { $0 } }
    task.cancel()
    let result = await task.value
    try await waitUntil { terminated.withLock { $0 } }

    #expect(!secondStarted.withLock { $0 })
    #expect(result == nil)
}

@Test func cancellingExecuteForTestingCancelsMergedBranchesAndSkipsNestedConcat() async throws {
    let gate = ExecutionGate()
    let secondStarted = Mutex(false)
    let effect = Effect<Int>.merge {
        Effect.run {
            await gate.wait()
            return 1
        }
        Effect.concat {
            Effect.run {
                await gate.wait()
                return nil
            }
            Effect.run {
                secondStarted.withLock { $0 = true }
                return 2
            }
        }
    }
    let task = Task { await effect.executeForTesting() }
    defer {
        task.cancel()
        gate.open()
    }

    try await waitUntil { gate.started == 2 }
    task.cancel()
    gate.open()
    let result = await task.value

    #expect(!secondStarted.withLock { $0 })
    #expect(result == nil)
}

@Test func cancellingExecuteForTestingPreservesPreviouslyCollectedAction() async throws {
    let gate = ExecutionGate()
    let effect = Effect<Int>.run { 1 }.concat(.run {
        await gate.wait()
        return 2
    })
    let task = Task { await effect.executeForTesting() }
    defer {
        task.cancel()
        gate.open()
    }

    try await waitUntil { gate.started == 1 }
    task.cancel()
    gate.open()
    let result = await task.value

    #expect(result == 1)
}

@Test func executeForTestingCompletesComposedEffectsWithoutCancellation() async {
    let events = Mutex<[Int]>([])
    let effect = Effect<Int>.concat {
        Effect.merge {
            Effect.run {
                events.withLock { $0.append(1) }
                return 1
            }
            Effect.run {
                events.withLock { $0.append(2) }
                return 2
            }
        }
        Effect.run {
            events.withLock { $0.append(3) }
            return 3
        }
    }

    let result = await effect.executeForTesting()

    #expect(result == 3)
    #expect(events.withLock { Set($0) } == [1, 2, 3])
    #expect(events.withLock { $0.last } == 3)
}
