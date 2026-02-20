//
//  EffectRuntime.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Foundation

@MainActor
final class EffectRuntime<Action: Sendable> {
    private struct EffectTask {
        let id: UUID
        let lifetime: EffectLifetime
        let task: Task<Void, Never>
    }

    private var managedTasks: [UUID: EffectTask] = [:]
    private var replaceIndex: [AnyHashable: UUID] = [:]

    func run(
        _ effect: Effect<Action>,
        emit: @escaping @MainActor (Action) -> Void,
    ) {
        let id = UUID()

        if case let .replaceable(key) = effect.lifetime,
           let oldID = replaceIndex[key],
           let old = managedTasks.removeValue(forKey: oldID)
        {
            old.task.cancel()
            replaceIndex[key] = nil
        }

        let task = Task { [weak self] in
            if let next = await effect.execute(), !Task.isCancelled {
                await MainActor.run {
                    emit(next)
                }
            }
            await MainActor.run {
                self?.finish(id: id, lifetime: effect.lifetime)
            }
        }

        switch effect.lifetime {
        case let .replaceable(key):
            managedTasks[id] = EffectTask(
                id: id,
                lifetime: effect.lifetime,
                task: task,
            )
            replaceIndex[key] = id
        case .storeBound:
            managedTasks[id] = EffectTask(
                id: id,
                lifetime: effect.lifetime,
                task: task,
            )
        case .detached:
            break
        }
    }

    private func finish(id: UUID, lifetime: EffectLifetime) {
        _ = managedTasks.removeValue(forKey: id)
        if case let .replaceable(key) = lifetime, replaceIndex[key] == id {
            replaceIndex[key] = nil
        }
    }

    func cancelAll() {
        managedTasks.values.forEach { $0.task.cancel() }
        managedTasks.removeAll()
        replaceIndex.removeAll()
    }
}
