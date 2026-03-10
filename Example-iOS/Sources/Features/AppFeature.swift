//
//  AppFeature.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import NanoRedux
import Observation

enum AppFeature {
    @Observable final class State {
        fileprivate(set) var todo: TodoFeature.State
        fileprivate(set) var effects: EffectDemoFeature.State
        fileprivate(set) var settings: SettingsFeature.State

        init(
            todo: TodoFeature.State = .init(),
            effects: EffectDemoFeature.State = .init(),
            settings: SettingsFeature.State = .init(),
        ) {
            self.todo = todo
            self.effects = effects
            self.settings = settings
        }
    }

    enum Action: Sendable {
        case appLaunched
        case todo(TodoFeature.Action)
        case effects(EffectDemoFeature.Action)
        case settings(SettingsFeature.Action)
    }

    struct Dependencies: Sendable {
        let todo: TodoFeature.Dependencies
    }

    struct Reducer: NanoRedux.InjectableReducer {
        let dependencies: Dependencies
        private let todoReducer: TodoFeature.Reducer
        private let effectDemoReducer = EffectDemoFeature.Reducer()
        private let settingsReducer = SettingsFeature.Reducer()

        init(dependencies: Dependencies) {
            self.dependencies = dependencies
            todoReducer = TodoFeature.Reducer(dependencies: dependencies.todo)
        }

        func reduce(
            into state: inout State,
            action: Action,
        ) -> Effect<Action> {
            switch action {
            case .appLaunched:
                .run {
                    .todo(.onAppear)
                }

            case let .todo(childAction):
                todoReducer(
                    into: &state.todo,
                    action: childAction,
                ).map(namespace: Self.self) {
                    Action.todo($0)
                }

            case let .effects(childAction):
                effectDemoReducer(
                    into: &state.effects,
                    action: childAction,
                ).map(namespace: Self.self) {
                    Action.effects($0)
                }

            case let .settings(childAction):
                settingsReducer(
                    into: &state.settings,
                    action: childAction,
                ).mapNone()
            }
        }
    }
}
