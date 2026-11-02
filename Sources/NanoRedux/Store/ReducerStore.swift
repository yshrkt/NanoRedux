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
        @ObservationIgnored private var logName = ""
        @ObservationIgnored private var formatState: ((State) -> String)?
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
                    logAction(action)
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
                    logState()
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

    /// Configures debug logging on this root store and returns the same instance.
    ///
    /// State is logged immediately and after every processed action. The default name is
    /// the state type name. Omit `formatState` to use reflection. Each call replaces the
    /// previous configuration. Release builds do not format or emit logs.
    @discardableResult
    public func logging(
        _ options: LoggingOptions = .all,
        name: String? = nil,
        formatState: ((State) -> String)? = nil,
    ) -> Self {
        configureLogging(options, name: name, formatState: formatState, output: { print($0) })
        return self
    }

    func configureLogging(
        _ options: LoggingOptions,
        name: String? = nil,
        formatState: ((State) -> String)? = nil,
        output: @escaping (String) -> Void,
    ) {
        #if DEBUG
            loggingOptions = options
            logName = name ?? String(describing: State.self)
            self.formatState = formatState
            logOutput = output
            logState()
        #endif
    }

    #if DEBUG
        private func logAction(_ action: Action) {
            guard loggingOptions.contains(.action) else { return }
            logOutput("[\(logName)][Action] \(LogFormatter.format(action))")
        }

        private func logState() {
            guard loggingOptions.contains(.state) else { return }
            let description = formatState?(state) ?? LogFormatter.format(state)
            logOutput("[\(logName)][State] \(description)")
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
