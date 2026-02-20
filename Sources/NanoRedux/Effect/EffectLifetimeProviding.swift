//
//  EffectLifetimeProviding.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

public protocol EffectLifetimeProviding {
    var effectLifetime: EffectLifetime { get }
}

public extension EffectLifetimeProviding {
    var effectLifetime: EffectLifetime { .storeBound }
}
