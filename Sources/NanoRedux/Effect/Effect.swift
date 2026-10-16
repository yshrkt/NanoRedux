//
//  Effect.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Foundation

public struct Effect<Action: Sendable>: Sendable {
    indirect enum Operation<Output: Sendable> {
        case run(@Sendable () async -> Output?)
        case stream(@Sendable () -> AsyncStream<Output>)
        case concat([Effect<Output>])
        case merge([Effect<Output>])
        case throttle(
            key: EffectLifetime.ReplaceableKey,
            interval: Duration,
            effect: Effect<Output>,
        )
        case debounce(
            key: EffectLifetime.ReplaceableKey,
            interval: Duration,
            effect: Effect<Output>,
        )
    }

    public let lifetime: EffectLifetime
    let operation: Operation<Action>

    private init(
        lifetime: EffectLifetime,
        operation: Operation<Action>,
    ) {
        self.lifetime = lifetime
        self.operation = operation
    }

    public static var none: Self {
        .run { nil }
    }

    public static func run(
        lifetime: EffectLifetime = .storeBound,
        _ run: @escaping @Sendable () async -> Action?,
    ) -> Self {
        .init(lifetime: lifetime, operation: .run(run))
    }

    public static func stream<S: AsyncSequence & Sendable>(
        lifetime: EffectLifetime = .storeBound,
        _ sequence: @escaping @Sendable () -> S,
    ) -> Self where S.Element == Action, S.Failure == Never {
        .init(lifetime: lifetime, operation: .stream {
            AsyncStream { continuation in
                let task = Task {
                    for await element in sequence() {
                        guard !Task.isCancelled else { break }
                        continuation.yield(element)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        })
    }

    public static func concat(
        @EffectBuilder<Action> _ effects: () -> [Effect<Action>],
    ) -> Self {
        let effects = flattenConcat(effects())
        guard effects.count == 1 else {
            return .init(lifetime: .storeBound, operation: .concat(effects))
        }
        return effects[0]
    }

    public static func merge(
        @EffectBuilder<Action> _ effects: () -> [Effect<Action>],
    ) -> Self {
        let effects = flattenMerge(effects())
        guard effects.count == 1 else {
            return .init(lifetime: .storeBound, operation: .merge(effects))
        }
        return effects[0]
    }

    public func concat(_ other: Effect<Action>) -> Self {
        .concat {
            self
            other
        }
    }

    public func merge(_ other: Effect<Action>) -> Self {
        .merge {
            self
            other
        }
    }

    public static func throttle(
        for interval: Duration,
        key: some Hashable,
        namespace: Any.Type? = nil,
        effect: Effect<Action>,
    ) -> Self {
        .init(
            lifetime: .storeBound,
            operation: .throttle(
                key: .init(key, namespace: namespace.map(ObjectIdentifier.init)),
                interval: interval,
                effect: effect,
            ),
        )
    }

    public static func throttle(
        for interval: Duration,
        key: some Hashable,
        namespace: Any.Type? = nil,
        @EffectBuilder<Action> _ effects: () -> [Effect<Action>],
    ) -> Self {
        .throttle(
            for: interval,
            key: key,
            namespace: namespace,
            effect: .concat(effects),
        )
    }

    public static func debounce(
        for interval: Duration,
        key: some Hashable,
        namespace: Any.Type? = nil,
        effect: Effect<Action>,
    ) -> Self {
        .init(
            lifetime: .storeBound,
            operation: .debounce(
                key: .init(key, namespace: namespace.map(ObjectIdentifier.init)),
                interval: interval,
                effect: effect,
            ),
        )
    }

    public static func debounce(
        for interval: Duration,
        key: some Hashable,
        namespace: Any.Type? = nil,
        @EffectBuilder<Action> _ effects: () -> [Effect<Action>],
    ) -> Self {
        .debounce(
            for: interval,
            key: key,
            namespace: namespace,
            effect: .concat(effects),
        )
    }

    public func throttled(
        for interval: Duration,
        key: some Hashable,
        namespace: Any.Type? = nil,
    ) -> Self {
        .throttle(
            for: interval,
            key: key,
            namespace: namespace,
            effect: self,
        )
    }

    public func debounced(
        for interval: Duration,
        key: some Hashable,
        namespace: Any.Type? = nil,
    ) -> Self {
        .debounce(
            for: interval,
            key: key,
            namespace: namespace,
            effect: self,
        )
    }

    /// Executes the effect and returns the last collected action.
    /// Cancellation skips effects that have not started and ignores subsequent actions,
    /// preserving actions already collected. In-flight work must cooperate with task cancellation.
    public func execute() async -> Action? {
        let collector = ActionCollector<Action>()
        await collectActions { action in
            await collector.append(action)
        }
        return await collector.last
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
    static func flattenConcat(_ effects: [Effect<Action>]) -> [Effect<Action>] {
        var flattened: [Effect<Action>] = []
        flattened.reserveCapacity(effects.count)

        for effect in effects {
            switch effect.operation {
            case let .concat(nested):
                flattened.append(contentsOf: flattenConcat(nested))
            default:
                flattened.append(effect)
            }
        }

        return flattened
    }

    static func flattenMerge(_ effects: [Effect<Action>]) -> [Effect<Action>] {
        var flattened: [Effect<Action>] = []
        flattened.reserveCapacity(effects.count)

        for effect in effects {
            switch effect.operation {
            case let .merge(nested):
                flattened.append(contentsOf: flattenMerge(nested))
            default:
                flattened.append(effect)
            }
        }

        return flattened
    }

    func collectActions(
        _ emit: @escaping @Sendable (Action) async -> Void,
    ) async {
        guard !Task.isCancelled else { return }

        switch operation {
        case let .run(run):
            if let action = await run(), !Task.isCancelled {
                await emit(action)
            }

        case let .stream(stream):
            for await action in stream() {
                guard !Task.isCancelled else { return }
                await emit(action)
            }

        case let .concat(effects):
            for effect in effects {
                guard !Task.isCancelled else { return }
                await effect.collectActions(emit)
            }

        case let .merge(effects):
            await withTaskGroup(of: Void.self) { group in
                for effect in effects {
                    guard group.addTaskUnlessCancelled(operation: {
                        await effect.collectActions(emit)
                    }) else { break }
                }
            }

        case let .throttle(_, _, effect), let .debounce(_, _, effect):
            await effect.collectActions(emit)
        }
    }

    func mapAction<NewAction: Sendable>(
        _ transform: @escaping @Sendable (Action) -> NewAction,
    ) -> Effect<NewAction> {
        switch operation {
        case let .run(run):
            .init(lifetime: lifetime, operation: .run {
                await run().map(transform)
            })

        case let .stream(stream):
            .init(lifetime: lifetime, operation: .stream {
                AsyncStream { continuation in
                    let task = Task {
                        for await action in stream() {
                            guard !Task.isCancelled else { break }
                            continuation.yield(transform(action))
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { @Sendable _ in
                        task.cancel()
                    }
                }
            })

        case let .concat(effects):
            .init(
                lifetime: .storeBound,
                operation: .concat(effects.map { $0.mapAction(transform) }),
            )

        case let .merge(effects):
            .init(
                lifetime: .storeBound,
                operation: .merge(effects.map { $0.mapAction(transform) }),
            )

        case let .throttle(key, interval, effect):
            .init(
                lifetime: .storeBound,
                operation: .throttle(
                    key: key,
                    interval: interval,
                    effect: effect.mapAction(transform),
                ),
            )

        case let .debounce(key, interval, effect):
            .init(
                lifetime: .storeBound,
                operation: .debounce(
                    key: key,
                    interval: interval,
                    effect: effect.mapAction(transform),
                ),
            )
        }
    }

    func mapReplaceableKey(
        _ transform: @escaping (EffectLifetime.ReplaceableKey) -> EffectLifetime.ReplaceableKey,
    ) -> Effect<Action> {
        let newLifetime = lifetime.mapReplaceableKey(transform)
        let newOperation: Operation<Action> = switch operation {
        case let .run(run):
            .run(run)
        case let .stream(stream):
            .stream(stream)
        case let .concat(effects):
            .concat(effects.map { $0.mapReplaceableKey(transform) })
        case let .merge(effects):
            .merge(effects.map { $0.mapReplaceableKey(transform) })
        case let .throttle(key, interval, effect):
            .throttle(
                key: transform(key),
                interval: interval,
                effect: effect.mapReplaceableKey(transform),
            )
        case let .debounce(key, interval, effect):
            .debounce(
                key: transform(key),
                interval: interval,
                effect: effect.mapReplaceableKey(transform),
            )
        }
        return .init(lifetime: newLifetime, operation: newOperation)
    }
}

private actor ActionCollector<Action: Sendable> {
    private var actions: [Action] = []

    func append(_ action: Action) {
        guard !Task.isCancelled else { return }
        actions.append(action)
    }

    var last: Action? {
        actions.last
    }
}

private extension EffectLifetime {
    func mapReplaceableKey(
        _ transform: @escaping (EffectLifetime.ReplaceableKey) -> EffectLifetime.ReplaceableKey,
    ) -> Self {
        switch self {
        case let .replaceable(key):
            .replaceable(key: transform(key))
        case .storeBound:
            .storeBound
        case .detached:
            .detached
        }
    }
}
