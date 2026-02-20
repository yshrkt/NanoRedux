//
//  Effect.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Foundation

public struct Effect<Action: Sendable> {
    public let lifetime: EffectLifetime
    let run: @Sendable () async -> Action?

    private init(
        lifetime: EffectLifetime,
        run: @escaping @Sendable () async -> Action?,
    ) {
        self.lifetime = lifetime
        self.run = run
    }

    public static var none: Self {
        .run { nil }
    }

    public static func run(
        lifetime: EffectLifetime = .storeBound,
        _ run: @escaping @Sendable () async -> Action?,
    ) -> Self {
        .init(lifetime: lifetime, run: run)
    }

    public func execute() async -> Action? {
        await run()
    }

    public func map<NewAction: Sendable>(
        namespace: Any.Type = Self.self,
        _ action: @escaping @Sendable (Action) -> NewAction,
    ) -> Effect<NewAction> {
        mapAction(action).mapReplaceableKey {
            .init($0, namespace: ObjectIdentifier(namespace))
        }
    }

    public func mapNone<NewAction: Sendable>() -> Effect<NewAction> {
        .none
    }
}

private extension Effect {
    func mapAction<NewAction: Sendable>(
        _ transform: @escaping @Sendable (Action) -> NewAction,
    ) -> Effect<NewAction> {
        let run = run
        return .init(lifetime: lifetime) {
            await run().map(transform)
        }
    }

    func mapReplaceableKey(
        _ transform: @escaping (EffectLifetime.ReplaceableKey) -> EffectLifetime.ReplaceableKey,
    ) -> Effect<Action> {
        let newLifetime: EffectLifetime = switch lifetime {
        case let .replaceable(key):
            .replaceable(key: transform(key))
        case .storeBound:
            .storeBound
        case .detached:
            .detached
        }
        return .init(lifetime: newLifetime, run: run)
    }
}
