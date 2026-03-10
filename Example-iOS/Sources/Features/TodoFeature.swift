//
//  ToDoFeature.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import Foundation
import NanoRedux
import Observation

enum TodoFeature {
    @Observable final class State {
        fileprivate(set) var todos: [Todo]
        fileprivate(set) var inputText: String
        fileprivate(set) var isLoading: Bool
        fileprivate(set) var errorMessage: String?

        init(
            todos: [Todo] = [],
            inputText: String = "",
            isLoading: Bool = false,
            errorMessage: String? = nil,
        ) {
            self.todos = todos
            self.inputText = inputText
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    enum Action: Sendable, EffectLifetimeProviding {
        case onAppear
        case inputChanged(String)
        case addTapped
        case toggleTapped(UUID)
        case deleteTapped(UUID)
        case todosLoaded([Todo])
        case loadFailed(String)

        var effectLifetime: EffectLifetime {
            guard case .onAppear = self else {
                return .storeBound
            }
            return .replaceable("onAppear")
        }
    }

    struct Dependencies: Sendable {
        let repository: any TodoRepository
    }

    struct Reducer: NanoRedux.InjectableReducer {
        let dependencies: Dependencies

        func reduce(
            into state: inout State,
            action: Action,
        ) -> Effect<Action> {
            var effect: Effect<Action> = .none
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                effect = loadEffect(lifetime: action.effectLifetime)

            case let .inputChanged(text):
                state.inputText = text

            case .addTapped:
                let trimmed = state.inputText.trimmingCharacters(
                    in: .whitespacesAndNewlines,
                )
                guard !trimmed.isEmpty else { return .none }
                state.todos.insert(
                    Todo(id: UUID(), title: trimmed, isDone: false),
                    at: 0,
                )
                state.inputText = ""

            case let .toggleTapped(id):
                guard let index = state.todos.firstIndex(where: { $0.id == id }) else {
                    break
                }
                state.todos[index].isDone.toggle()

            case let .deleteTapped(id):
                state.todos.removeAll { $0.id == id }

            case let .todosLoaded(todos):
                state.isLoading = false
                state.todos = todos

            case let .loadFailed(message):
                state.isLoading = false
                state.errorMessage = message
            }

            return effect
        }

        private func loadEffect(lifetime: EffectLifetime) -> Effect<Action> {
            .run(lifetime: lifetime) {
                do {
                    return try await .todosLoaded(dependencies.repository.fetchTodos())
                } catch is CancellationError {
                    return nil
                } catch {
                    return .loadFailed(error.localizedDescription)
                }
            }
        }
    }
}
