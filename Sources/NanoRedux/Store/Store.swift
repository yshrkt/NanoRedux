import Observation

/// The observable state and action interface shared by root and scoped stores.
@MainActor
public protocol Store<State, Action>: AnyObject, Observable {
    associatedtype State: Observable
    associatedtype Action: Sendable

    var state: State { get }
    func send(_ action: Action)
}

public extension Store {
    /// Derives a child store that retains its parent and forwards actions to it.
    func scope<ChildState: Observable, ChildAction: Sendable>(
        state toChildState: @escaping (State) -> ChildState,
        action toParentAction: @escaping (ChildAction) -> Action,
    ) -> some Store<ChildState, ChildAction> {
        ScopedStore(
            parent: self,
            toLocalState: toChildState,
            toParentAction: toParentAction,
        )
    }
}
