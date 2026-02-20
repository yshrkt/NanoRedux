//
//  Storing.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Observation

@MainActor
protocol Storing: AnyObject {
    associatedtype State: Observable
    associatedtype Action: Sendable

    var state: State { get }
    func send(_ action: Action)
}
