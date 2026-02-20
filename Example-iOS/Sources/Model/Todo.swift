//
//  Todo.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import Foundation

struct Todo: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var isDone: Bool
}

protocol TodoRepository: Sendable {
    func fetchTodos() async throws -> [Todo]
}

struct MockTodoRepository: TodoRepository {
    func fetchTodos() async throws -> [Todo] {
        try await Task.sleep(for: .milliseconds(300))
        return [
            Todo(id: UUID(), title: "Buy milk", isDone: false),
            Todo(id: UUID(), title: "Walk 20 minutes", isDone: true),
        ]
    }
}
