//
//  ReducerStore.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Observation

@MainActor
@Observable
final class ReducerStore<R: Reducer>: Storing {
    typealias State = R.State
    typealias Action = R.Action

    private let reducer: R
    private let runtime = EffectRuntime<Action>()
    @ObservationIgnored private var continuation: AsyncStream<Action>.Continuation?

    private(set) var state: State
    @ObservationIgnored private var loopTask: Task<Void, Never>?

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
                var nextState = self.state
                let effect = self.reducer(
                    into: &nextState,
                    action: action,
                )
                // Reference states track their own properties; notify at the root only on replacement.
                if !(State.self is AnyObject.Type) || self.state as AnyObject !== nextState as AnyObject {
                    self.state = nextState
                }
                self.runtime.run(effect) { [weak self] nextAction in
                    self?.continuation?.yield(nextAction)
                }
            }
        }
    }

    func send(_ action: Action) {
        continuation?.yield(action)
    }
    
    // Workaround for release build issue
    // https://github.com/swiftlang/swift/issues/87462#issuecomment-4030739626
    @_optimize(none) isolated deinit {
        continuation?.finish()
        loopTask?.cancel()
        runtime.cancelAll()
    }
}
