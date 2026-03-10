//
//  EffectDemoFeature.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/03/09.
//

import Foundation
import NanoRedux
import Observation

enum EffectDemoFeature {
    @Observable final class State {
        fileprivate(set) var debounceInputText: String
        fileprivate(set) var debouncedText: String
        fileprivate(set) var throttleCount: Int
        fileprivate(set) var logs: [EffectDemoLog]

        init(
            debounceInputText: String = "",
            debouncedText: String = "",
            throttleCount: Int = 0,
            logs: [EffectDemoLog] = [],
        ) {
            self.debounceInputText = debounceInputText
            self.debouncedText = debouncedText
            self.throttleCount = throttleCount
            self.logs = logs
        }
    }

    enum Action: Sendable {
        case concatTapped
        case mergeTapped
        case throttleTapped
        case debounceInputChanged(String)
        case resetTapped
        case logAdded(String)
        case debouncedTextUpdated(String)
        case throttleTriggered
    }

    struct Reducer: NanoRedux.Reducer {
        func reduce(
            into state: inout State,
            action: Action,
        ) -> Effect<Action> {
            switch action {
            case .concatTapped:
                return .concat {
                    Effect.run {
                        .logAdded("concat step 1")
                    }
                    Effect.run {
                        try? await Task.sleep(for: .milliseconds(300))
                        return .logAdded("concat step 2")
                    }
                }

            case .mergeTapped:
                return .merge {
                    Effect.run {
                        try? await Task.sleep(for: .milliseconds(150))
                        return .logAdded("merge fast branch")
                    }
                    Effect.run {
                        try? await Task.sleep(for: .milliseconds(350))
                        return .logAdded("merge slow branch")
                    }
                }

            case .throttleTapped:
                return .throttle(for: .seconds(1), key: "effect-demo-throttle") {
                    Effect.run { .throttleTriggered }
                }

            case let .debounceInputChanged(text):
                state.debounceInputText = text
                return .debounce(for: .milliseconds(400), key: "effect-demo-debounce") {
                    Effect.run { .debouncedTextUpdated(text) }
                }

            case .resetTapped:
                state.debounceInputText = ""
                state.debouncedText = ""
                state.throttleCount = 0
                state.logs = []
                return .none

            case let .logAdded(message):
                appendLog(message, to: &state)
                return .none

            case let .debouncedTextUpdated(text):
                state.debouncedText = text
                appendLog("debounce committed: \(text)", to: &state)
                return .none

            case .throttleTriggered:
                state.throttleCount += 1
                appendLog("throttle fired: \(state.throttleCount)", to: &state)
                return .none
            }
        }

        private func appendLog(_ message: String, to state: inout State) {
            state.logs.insert(.init(message: message), at: 0)
            state.logs = Array(state.logs.prefix(8))
        }
    }
}
