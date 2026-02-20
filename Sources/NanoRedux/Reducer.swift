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
    associatedtype Dependencies

    func callAsFunction(
        into state: inout State,
        action: Action,
        dependencies: Dependencies,
    ) -> Effect<Action>
}
