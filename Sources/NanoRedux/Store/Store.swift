//
//  Store.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Foundation
import Observation

@MainActor
@Observable
public final class Store<State: Observable, Action: Sendable>: Storing {
    private let core: any Storing
    private let _state: () -> State
    private let _send: (Action) -> Void

    public var state: State {
        _state()
    }

    private init<Core: Storing>(_ core: Core) where Core.State == State, Core.Action == Action {
        _state = { core.state }
        _send = core.send
        self.core = core
    }

    public func send(_ action: Action) {
        _send(action)
    }

    public static func reducer<R: Reducer>(
        initialState: State,
        reducer: R,
    ) -> Store<State, Action> where R.State == State, R.Action == Action {
        Store(
            ReducerStore(
                initialState: initialState,
                reducer: reducer,
            ),
        )
    }

    public func scope<ChildState, ChildAction>(
        state toChildState: @escaping (State) -> ChildState,
        action toParentAction: @escaping (ChildAction) -> Action,
    ) -> Store<ChildState, ChildAction> {
        Store<ChildState, ChildAction>.scope(
            parent: self,
            toLocalState: toChildState,
            toParentAction: toParentAction,
        )
    }

    private static func scope<ParentState, ParentAction>(
        parent: Store<ParentState, ParentAction>,
        toLocalState: @escaping (ParentState) -> State,
        toParentAction: @escaping (Action) -> ParentAction,
    ) -> Store<State, Action> {
        Store(
            ScopedStore(
                parent: parent,
                toLocalState: toLocalState,
                toParentAction: toParentAction,
            ),
        )
    }
}
