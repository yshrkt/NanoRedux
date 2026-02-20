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
        fileprivate(set) var settings: SettingsFeature.State

        init(
            todo: TodoFeature.State = .init(),
            settings: SettingsFeature.State = .init(),
        ) {
            self.todo = todo
            self.settings = settings
        }
    }

    enum Action: Sendable {
        case appLaunched
        case todo(TodoFeature.Action)
        case settings(SettingsFeature.Action)
    }

    struct Dependencies: Sendable {
        let todo: TodoFeature.Dependencies
    }

    struct Reducer: NanoRedux.Reducer {
        private let todoReducer = TodoFeature.Reducer()
        private let settingsReducer = SettingsFeature.Reducer()

        init() {}

        func callAsFunction(
            into state: inout State,
            action: Action,
            dependencies: Dependencies,
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
                    dependencies: dependencies.todo,
                ).map(namespace: Self.self) {
                    Action.todo($0)
                }

            case let .settings(childAction):
                settingsReducer(
                    into: &state.settings,
                    action: childAction,
                    dependencies: (),
                ).mapNone()
            }
        }
    }
}
