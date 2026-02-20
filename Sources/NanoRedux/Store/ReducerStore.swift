//
//  ReducerStore.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

@MainActor
final class ReducerStore<R: Reducer>: Storing {
    typealias State = R.State
    typealias Action = R.Action

    private enum Constants {
        static var actionBufferLimit: Int { 256 }
    }

    private let reducer: R
    private let dependencies: R.Dependencies
    private let runtime = EffectRuntime<Action>()
    private var continuation: AsyncStream<Action>.Continuation?

    private(set) var state: State
    private var loopTask: Task<Void, Never>?

    init(
        initialState: State,
        reducer: R,
        dependencies: R.Dependencies,
    ) {
        state = initialState
        self.reducer = reducer
        self.dependencies = dependencies

        let stream = AsyncStream<Action>(
            bufferingPolicy: .bufferingNewest(Constants.actionBufferLimit),
        ) { [weak self] continuation in
            self?.continuation = continuation
        }

        loopTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await action in stream {
                let effect = self.reducer(
                    into: &state,
                    action: action,
                    dependencies: self.dependencies,
                )
                runtime.run(effect) { [weak self] nextAction in
                    self?.continuation?.yield(nextAction)
                }
            }
        }
    }

    func send(_ action: Action) {
        let result = continuation?.yield(action)
        #if DEBUG
            if case .dropped = result {
                assertionFailure("Action dropped: buffer limit=\(Constants.actionBufferLimit)")
            }
        #endif
    }

    @MainActor deinit {
        continuation?.finish()
        loopTask?.cancel()
        runtime.cancelAll()
    }
}
