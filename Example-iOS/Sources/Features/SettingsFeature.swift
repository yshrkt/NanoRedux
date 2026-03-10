//
//  SettingsFeature.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import NanoRedux
import Observation

enum SettingsFeature {
    @Observable final class State {
        fileprivate(set) var notificationsEnabled: Bool

        init(notificationsEnabled: Bool = false) {
            self.notificationsEnabled = notificationsEnabled
        }
    }

    enum Action: Sendable {
        case toggleNotifications(Bool)
    }

    struct Reducer: NanoRedux.Reducer {
        func reduce(
            into state: inout State,
            action: Action,
        ) -> Effect<Action> {
            switch action {
            case let .toggleNotifications(isEnabled):
                state.notificationsEnabled = isEnabled
                return .none
            }
        }
    }
}
