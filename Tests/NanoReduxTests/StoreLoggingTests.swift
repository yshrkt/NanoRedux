@testable import NanoRedux
import Observation
import Testing

@Observable
private final class LoggedState {
    var count = 0
}

private enum LoggedAction: Sendable {
    case increment
    case start
}

private struct LoggedReducer: Reducer {
    func reduce(into state: inout LoggedState, action: LoggedAction) -> Effect<LoggedAction> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .start:
            return .run { .increment }
        }
    }
}

@MainActor
private func waitForCount(_ expected: Int, in state: LoggedState) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while state.count != expected, clock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(state.count == expected)
}

@MainActor
@Test(arguments: [LoggingOptions(), .action, .state, .all])
func storeLoggingOptionsAndEffectActions(options: LoggingOptions) async throws {
    let state = LoggedState()
    let store = ReducerStore(initialState: state, reducer: LoggedReducer())
    var logs: [String] = []
    store.configureLogging(options) { logs.append($0) }
    store.send(.start)
    try await waitForCount(1, in: state)

    #if DEBUG
        let actions = logs.filter { $0.contains("[Action] ") }
        let states = logs.filter { $0.contains("[State] ") }
        #expect(actions.count == (options.contains(.action) ? 2 : 0))
        #expect(states.count == (options.contains(.state) ? 3 : 0))
        if options.contains(.action) {
            #expect(actions == ["[LoggedState][Action] start", "[LoggedState][Action] increment"])
        }
        if options.contains(.state) {
            #expect(states[0].contains("_count: 0"))
            #expect(states[1].contains("_count: 0"))
            #expect(states[2].contains("_count: 1"))
        }
        if options == .all {
            #expect(logs.map { $0.contains("[Action]") } == [false, true, false, true, false])
        }
    #else
        #expect(logs.isEmpty)
    #endif
}

@MainActor
@Test func storeLoggingCanBeDisabledAndReconfigured() async throws {
    let state = LoggedState()
    let store = ReducerStore(initialState: state, reducer: LoggedReducer())
    var logs: [String] = []
    store.configureLogging(.all) { logs.append($0) }
    let initialCount = logs.count
    store.configureLogging([]) { logs.append($0) }
    store.send(.increment)
    try await waitForCount(1, in: state)
    #expect(logs.count == initialCount)

    store.configureLogging(.state) { logs.append($0) }
    #if DEBUG
        #expect(logs.count == initialCount + 1)
        #expect(logs.last?.contains("_count: 1") == true)
    #else
        #expect(logs.isEmpty)
    #endif
}

@MainActor
@Test func rootLoggingIncludesScopedActions() async throws {
    enum ChildAction: Sendable { case tap }
    let root = StoreBuilder.reducer(initialState: LoggedState(), reducer: LoggedReducer())
    let child = root.scope(state: { $0 }, action: { (_: ChildAction) in LoggedAction.increment })
    var logs: [String] = []
    root.configureLogging(.all) { logs.append($0) }
    child.send(.tap)
    try await waitForCount(1, in: root.state)
    #if DEBUG
        #expect(logs.count == 3)
        #expect(logs[1].contains("increment"))
        #expect(logs[2].contains("_count: 1"))
    #else
        #expect(logs.isEmpty)
    #endif
    #expect(root.logging([]) === root)
}

@MainActor
@Test func customStateLoggingBeforeTypeErasureIncludesEffectResults() async throws {
    var snapshots: [Int] = []
    let root = StoreBuilder.reducer(initialState: LoggedState(), reducer: LoggedReducer())
    let store: any Store<LoggedState, LoggedAction> = root.logging(.state, name: "Counter") { state in
        snapshots.append(state.count)
        return "count: \(state.count)"
    }
    #expect(store === root)
    store.send(.start)
    try await waitForCount(1, in: store.state)
    #if DEBUG
        #expect(snapshots == [0, 0, 1])
    #else
        #expect(snapshots.isEmpty)
    #endif
}

@MainActor
@Test func loggingNamesDistinguishStoresAndConfigurationCanBeReset() async throws {
    let first = StoreBuilder.reducer(initialState: LoggedState(), reducer: LoggedReducer())
    let second = StoreBuilder.reducer(initialState: LoggedState(), reducer: LoggedReducer())
    var firstLogs: [String] = []
    var secondLogs: [String] = []
    first.configureLogging(
        .all, name: "First", formatState: { "count: \($0.count)" }, output: { firstLogs.append($0) },
    )
    second.configureLogging(
        .all, name: "Second", formatState: { "count: \($0.count)" }, output: { secondLogs.append($0) },
    )
    first.send(.increment)
    second.send(.increment)
    try await waitForCount(1, in: first.state)
    try await waitForCount(1, in: second.state)
    #if DEBUG
        #expect(firstLogs == ["[First][State] count: 0", "[First][Action] increment", "[First][State] count: 1"])
        #expect(secondLogs == ["[Second][State] count: 0", "[Second][Action] increment", "[Second][State] count: 1"])
    #else
        #expect(firstLogs.isEmpty)
        #expect(secondLogs.isEmpty)
    #endif

    first.configureLogging(.state) { firstLogs.append($0) }
    #if DEBUG
        #expect(firstLogs.last?.hasPrefix("[LoggedState][State]") == true)
        #expect(firstLogs.last?.contains("_count: 1") == true)
    #else
        #expect(firstLogs.isEmpty)
    #endif
}

@MainActor
@Test(arguments: [LoggingOptions(), .action])
func customStateFormatterIsNotCalledWhenStateLoggingIsDisabled(options: LoggingOptions) async throws {
    let store = StoreBuilder.reducer(initialState: LoggedState(), reducer: LoggedReducer())
        .logging(options, name: "Disabled") { _ in
            Issue.record("State formatting must be skipped when state logging is disabled")
            return "unexpected"
        }
    store.send(.increment)
    try await waitForCount(1, in: store.state)
}

@MainActor
@Test func customStateFormatterReadsReplacementState() async throws {
    struct ReplacingReducer: Reducer {
        func reduce(into state: inout LoggedState, action: Int) -> Effect<Int> {
            state = LoggedState()
            state.count = action
            return .none
        }
    }
    let original = LoggedState()
    let store = StoreBuilder.reducer(initialState: original, reducer: ReplacingReducer())
    var logs: [String] = []
    store.configureLogging(
        .state, name: "Replacing", formatState: { "count: \($0.count)" }, output: { logs.append($0) },
    )
    store.send(5)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while store.state.count != 5, clock.now < deadline {
        try await Task.sleep(for: .milliseconds(1))
    }
    try #require(store.state.count == 5)
    #expect(store.state !== original)
    #if DEBUG
        #expect(logs == ["[Replacing][State] count: 0", "[Replacing][State] count: 5"])
    #else
        #expect(logs.isEmpty)
    #endif
}

#if DEBUG
    @Test func loggingStopsAtInternalPropertiesThroughoutNestedStates() {
        struct InternalValue: CustomReflectable {
            var customMirror: Mirror {
                Issue.record("An internal property must not be reflected")
                return Mirror(self, children: [:])
            }
        }
        struct Nested: CustomReflectable {
            var customMirror: Mirror {
                Mirror(self, children: ["_$internal": InternalValue(), "value": 42])
            }
        }
        let output = LogFormatter.format([Nested()])
        #expect(output.contains("_$internal: InternalValue (omitted)"))
        #expect(output.contains("value: 42"))

        let observableOutput = LogFormatter.format(LoggedState())
        #expect(observableOutput.contains("_count: 0"))
        #expect(observableOutput.contains("_$observationRegistrar: ObservationRegistrar (omitted)"))
        #expect(!observableOutput.contains("extent:"))
    }

    @Test func loggingHandlesCyclesAndLimitsOutput() {
        final class Node {
            var next: Node?
        }
        let node = Node()
        node.next = node
        #expect(LogFormatter.format(node).contains("(cycle)"))
        node.next = nil

        let head = Node()
        var tail = head
        for _ in 0 ..< 20 {
            let next = Node()
            tail.next = next
            tail = next
        }
        #expect(LogFormatter.format(head).contains("(omitted)"))
        #expect(LogFormatter.format(Array(0 ..< 101)).contains("child limit reached"))
    }

    @MainActor
    @Test func disabledLoggingDoesNotReflectState() async throws {
        final class State: Observable, CustomReflectable {
            var count = 0
            var customMirror: Mirror {
                Issue.record("Disabled logging must not reflect state")
                return Mirror(self, children: [:])
            }
        }
        struct TestReducer: Reducer {
            func reduce(into state: inout State, action: Int) -> Effect<Int> {
                state.count = action
                return .none
            }
        }
        let store = StoreBuilder.reducer(initialState: State(), reducer: TestReducer()).logging([])
        store.send(1)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while store.state.count != 1, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(store.state.count == 1)
    }
#endif
