//
//  TodoView.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import NanoRedux
import SwiftUI

struct TodoView: View {
    @State private var store: Store<TodoFeature.State, TodoFeature.Action>

    init(store: Store<TodoFeature.State, TodoFeature.Action>) {
        self.store = store
    }

    var body: some View {
        let _ = Self._printChanges()
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        TextField(
                            "Add a todo",
                            text: Binding(
                                get: { store.state.inputText },
                                set: { store.send(.inputChanged($0)) },
                            ),
                        )
                        .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            store.send(.addTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let message = store.state.errorMessage {
                        Text(message)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()

                List {
                    ForEach(store.state.todos) { todo in
                        HStack(spacing: 12) {
                            Button {
                                store.send(.toggleTapped(todo.id))
                            } label: {
                                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)

                            Text(todo.title)
                                .strikethrough(todo.isDone)
                                .foregroundStyle(todo.isDone ? .secondary : .primary)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.state.todos[$0].id }
                        ids.forEach { store.send(.deleteTapped($0)) }
                    }
                }
                .overlay {
                    if store.state.isLoading {
                        ProgressView("Loading...")
                    }
                }
            }
            .navigationTitle("Todos")
            .task {
                if store.state.todos.isEmpty, !store.state.isLoading {
                    store.send(.onAppear)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reload") {
                        store.send(.onAppear)
                    }
                }
            }
        }
    }
}

#Preview {
    TodoView(store: .reducer(
        initialState: .init(),
        reducer: TodoFeature.Reducer(),
        dependencies: TodoFeature.Dependencies(repository: MockTodoRepository()),
    ))
}
