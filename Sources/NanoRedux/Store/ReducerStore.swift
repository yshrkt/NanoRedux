//
//  ReducerStore.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Observation

@MainActor
@Observable
public final class ReducerStore<R: Reducer>: Store {
    public typealias State = R.State
    public typealias Action = R.Action

    private let reducer: R
    private let runtime = EffectRuntime<Action>()
    @ObservationIgnored private var continuation: AsyncStream<Action>.Continuation?

    public private(set) var state: State
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    #if DEBUG
        @ObservationIgnored private var loggingOptions: LoggingOptions = []
        @ObservationIgnored private var logOutput: (String) -> Void = { print($0) }
    #endif

    init(
        initialState: State,
        reducer: R,
    ) {
        state = initialState
        self.reducer = reducer

        let stream = AsyncStream<Action>(
            bufferingPolicy: .unbounded,
        ) { [weak self] continuation in
            self?.continuation = continuation
        }

        loopTask = Task { @MainActor [weak self] in
            for await action in stream {
                // Retain the store only while processing an action, not while waiting for one.
                guard let self else { return }
                #if DEBUG
                    log(action, option: .action, label: "Action")
                #endif
                var nextState = state
                let effect = self.reducer(
                    into: &nextState,
                    action: action,
                )
                // Reference states track their own properties; notify at the root only on replacement.
                if !(State.self is AnyObject.Type) || state as AnyObject !== nextState as AnyObject {
                    state = nextState
                }
                #if DEBUG
                    log(state, option: .state, label: "State")
                #endif
                runtime.run(effect) { [weak self] nextAction in
                    self?.continuation?.yield(nextAction)
                }
            }
        }
    }

    public func send(_ action: Action) {
        continuation?.yield(action)
    }

    /// Enables debug logging on this root store and returns the same instance.
    @discardableResult
    public func logging(_ options: LoggingOptions = .all) -> Self {
        configureLogging(options, output: { print($0) })
        return self
    }

    func configureLogging(_ options: LoggingOptions, output: @escaping (String) -> Void) {
        #if DEBUG
            loggingOptions = options
            logOutput = output
            log(state, option: .state, label: "State")
        #endif
    }

    #if DEBUG
        private func log(_ value: Any, option: LoggingOptions, label: String) {
            guard loggingOptions.contains(option) else { return }
            logOutput("[\(label)] \(LogFormatter.format(value))")
        }
    #endif

    // Workaround for release build issue
    // https://github.com/swiftlang/swift/issues/87462#issuecomment-4030739626
    @_optimize(none) isolated deinit {
        continuation?.finish()
        loopTask?.cancel()
        runtime.cancelAll()
    }
}
