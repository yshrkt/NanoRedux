//
//  EffectLifetime.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

public enum EffectLifetime: Equatable {
    // Cancels automatically when the store is deinitialized.
    case storeBound
    // Replaces any in-flight effect that shares the same key.
    case replaceable(key: ReplaceableKey)
    // Continues independently of the store lifecycle.
    case detached
}

public extension EffectLifetime {
    struct ReplaceableKey: Hashable {
        public let namespace: ObjectIdentifier?
        public let key: AnyHashable

        public init<Key: Hashable>(_ key: Key, namespace: ObjectIdentifier? = nil) {
            self.namespace = namespace
            self.key = AnyHashable(key)
        }
    }

    static func replaceable<Key: Hashable>(_ key: Key) -> Self {
        .replaceable(key: .init(key))
    }
}
