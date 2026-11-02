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
        let actions = logs.filter { $0.hasPrefix("[Action]") }
        let states = logs.filter { $0.hasPrefix("[State]") }
        #expect(actions.count == (options.contains(.action) ? 2 : 0))
        #expect(states.count == (options.contains(.state) ? 3 : 0))
        if options.contains(.action) {
            #expect(actions == ["[Action] start", "[Action] increment"])
        }
        if options.contains(.state) {
            #expect(states[0].contains("_count: 0"))
            #expect(states[1].contains("_count: 0"))
            #expect(states[2].contains("_count: 1"))
        }
        if options == .all {
            #expect(logs.map { String($0.prefix(8)) } == ["[State] ", "[Action]", "[State] ", "[Action]", "[State] "])
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
@Test func scopedLoggingUsesRootStateAndMappedActions() async throws {
    enum ChildAction: Sendable { case tap }
    let root = Store.reducer(initialState: LoggedState(), reducer: LoggedReducer())
    let child = root.scope(state: { $0 }, action: { (_: ChildAction) in LoggedAction.increment })
    var logs: [String] = []
    child.configureLogging(.all) { logs.append($0) }
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
    #expect(child.logging([]) === child)
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
        let store = Store.reducer(initialState: State(), reducer: TestReducer()).logging([])
        store.send(1)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while store.state.count != 1, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(store.state.count == 1)
    }
#endif
