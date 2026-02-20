//
//  ScopedStore.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Observation

@MainActor
final class ScopedStore<Parent: Storing, LocalState: Observable, LocalAction: Sendable>: Storing {
    private let parent: Parent
    private let toLocalState: (Parent.State) -> LocalState
    private let toParentAction: (LocalAction) -> Parent.Action

    var state: LocalState {
        toLocalState(parent.state)
    }

    init(
        parent: Parent,
        toLocalState: @escaping (Parent.State) -> LocalState,
        toParentAction: @escaping (LocalAction) -> Parent.Action,
    ) {
        self.parent = parent
        self.toLocalState = toLocalState
        self.toParentAction = toParentAction
    }

    func send(_ action: LocalAction) {
        parent.send(toParentAction(action))
    }
}
