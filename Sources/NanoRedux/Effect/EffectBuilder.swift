//
//  EffectBuilder.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/03/09.
//

@resultBuilder
public enum EffectBuilder<Action: Sendable> {
    public static func buildExpression(_ expression: Effect<Action>) -> [Effect<Action>] {
        [expression]
    }

    public static func buildBlock(_ components: [Effect<Action>]...) -> [Effect<Action>] {
        components.flatMap(\.self)
    }

    public static func buildEither(first component: [Effect<Action>]) -> [Effect<Action>] {
        component
    }

    public static func buildEither(second component: [Effect<Action>]) -> [Effect<Action>] {
        component
    }

    public static func buildOptional(_ component: [Effect<Action>]?) -> [Effect<Action>] {
        component ?? []
    }

    public static func buildArray(_ components: [[Effect<Action>]]) -> [Effect<Action>] {
        components.flatMap(\.self)
    }

    public static func buildLimitedAvailability(_ component: [Effect<Action>]) -> [Effect<Action>] {
        component
    }
}
