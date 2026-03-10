//
//  Reducer.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Observation

public protocol Reducer {
    associatedtype State: Observable
    associatedtype Action: Sendable

    func reduce(
        into state: inout State,
        action: Action,
    ) -> Effect<Action>
}

public extension Reducer {
    func callAsFunction(
        into state: inout State,
        action: Action,
    ) -> Effect<Action> {
        reduce(into: &state, action: action)
    }
}

public protocol InjectableReducer: Reducer {
    associatedtype Dependencies

    var dependencies: Dependencies { get }
    init(dependencies: Dependencies)
}
