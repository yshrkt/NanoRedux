//
//  EffectRuntime.swift
//  NanoRedux
//
//  Created by Yoshihiro Kato on 2026/02/20.
//

import Foundation

@MainActor
final class EffectRuntime<Action: Sendable> {
    private enum ManagedKind {
        case plain
        case replaceable(EffectLifetime.ReplaceableKey)
        case debounce(EffectLifetime.ReplaceableKey)
    }

    private struct EffectTask {
        let id: UUID
        let kind: ManagedKind
        let task: Task<Void, Never>
    }

    private var managedTasks: [UUID: EffectTask] = [:]
    private var replaceIndex: [EffectLifetime.ReplaceableKey: UUID] = [:]
    private var debounceIndex: [EffectLifetime.ReplaceableKey: UUID] = [:]
    private var throttleUntil: [EffectLifetime.ReplaceableKey: ContinuousClock.Instant] = [:]
    private let clock = ContinuousClock()

    func run(
        _ effect: Effect<Action>,
        emit: @escaping @MainActor (Action) -> Void,
    ) {
        let id = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            _ = await start(effect, emit: emit)
            await MainActor.run {
                self.finish(id: id, kind: .plain)
            }
        }
        register(id: id, kind: .plain, task: task)
    }

    func cancelAll() {
        managedTasks.values.forEach { $0.task.cancel() }
        managedTasks.removeAll()
        replaceIndex.removeAll()
        debounceIndex.removeAll()
        throttleUntil.removeAll()
    }
}

private extension EffectRuntime {
    enum ExecutionResult: Equatable {
        case completed
        case cancelled
    }

    func start(
        _ effect: Effect<Action>,
        emit: @escaping @MainActor (Action) -> Void,
    ) async -> ExecutionResult {
        switch effect.operation {
        case let .run(run):
            return await startLeaf(
                lifetime: effect.lifetime,
                run: run,
                emit: emit,
            )

        case let .stream(stream):
            return await startStream(
                lifetime: effect.lifetime,
                stream: stream,
                emit: emit,
            )

        case let .concat(effects):
            for effect in effects {
                if await start(effect, emit: emit) == .cancelled {
                    return .cancelled
                }
            }
            return .completed

        case let .merge(effects):
            return await withTaskGroup(of: ExecutionResult.self) { group in
                for effect in effects {
                    group.addTask { [weak self] in
                        guard let self else { return .cancelled }
                        return await start(effect, emit: emit)
                    }
                }

                var cancelled = false
                for await result in group {
                    if result == .cancelled {
                        cancelled = true
                    }
                }
                return cancelled ? .cancelled : .completed
            }

        case let .throttle(key, interval, effect):
            return await startThrottle(
                key: key,
                interval: interval,
                effect: effect,
                emit: emit,
            )

        case let .debounce(key, interval, effect):
            return await startDebounce(
                key: key,
                interval: interval,
                effect: effect,
                emit: emit,
            )
        }
    }

    func startLeaf(
        lifetime: EffectLifetime,
        run: @escaping @Sendable () async -> Action?,
        emit: @escaping @MainActor (Action) -> Void,
    ) async -> ExecutionResult {
        let task = Task<Void, Never> {
            if let next = await run(), !Task.isCancelled {
                await MainActor.run {
                    emit(next)
                }
            }
        }

        switch lifetime {
        case let .replaceable(key):
            return await awaitManaged(task, kind: .replaceable(key))
        case .storeBound:
            return await awaitManaged(task, kind: .plain)
        case .detached:
            return .completed
        }
    }

    func startStream(
        lifetime: EffectLifetime,
        stream: @escaping @Sendable () -> AsyncStream<Action>,
        emit: @escaping @MainActor (Action) -> Void,
    ) async -> ExecutionResult {
        let task = Task<Void, Never> {
            for await action in stream() {
                if Task.isCancelled { break }
                await MainActor.run {
                    emit(action)
                }
            }
        }

        switch lifetime {
        case let .replaceable(key):
            return await awaitManaged(task, kind: .replaceable(key))
        case .storeBound:
            return await awaitManaged(task, kind: .plain)
        case .detached:
            return .completed
        }
    }

    func startThrottle(
        key: EffectLifetime.ReplaceableKey,
        interval: Duration,
        effect: Effect<Action>,
        emit: @escaping @MainActor (Action) -> Void,
    ) async -> ExecutionResult {
        let now = clock.now
        if let until = throttleUntil[key], until > now {
            return .completed
        }

        throttleUntil[key] = now.advanced(by: interval)
        return await start(effect, emit: emit)
    }

    func startDebounce(
        key: EffectLifetime.ReplaceableKey,
        interval: Duration,
        effect: Effect<Action>,
        emit: @escaping @MainActor (Action) -> Void,
    ) async -> ExecutionResult {
        let task = Task<ExecutionResult, Never> { [weak self] in
            do {
                try await Task.sleep(for: interval)
            } catch {
                return .cancelled
            }

            guard let self, !Task.isCancelled else {
                return .cancelled
            }
            return await start(effect, emit: emit)
        }

        return await awaitManaged(task, kind: .debounce(key))
    }

    private func awaitManaged(
        _ task: Task<Void, Never>,
        kind: ManagedKind,
    ) async -> ExecutionResult {
        let id = register(kind: kind, task: task)

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        finish(id: id, kind: kind)
        return task.isCancelled ? .cancelled : .completed
    }

    private func awaitManaged(
        _ task: Task<ExecutionResult, Never>,
        kind: ManagedKind,
    ) async -> ExecutionResult {
        let wrappedTask = Task<Void, Never> {
            await withTaskCancellationHandler {
                _ = await task.value
            } onCancel: {
                task.cancel()
            }
        }
        let id = register(kind: kind, task: wrappedTask)

        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
            wrappedTask.cancel()
        }

        finish(id: id, kind: kind)
        return task.isCancelled ? .cancelled : result
    }

    @discardableResult
    private func register(
        id: UUID = UUID(),
        kind: ManagedKind,
        task: Task<Void, Never>,
    ) -> UUID {
        switch kind {
        case let .replaceable(key):
            if let oldID = replaceIndex[key],
               let old = managedTasks.removeValue(forKey: oldID)
            {
                old.task.cancel()
            }
            replaceIndex[key] = id

        case let .debounce(key):
            if let oldID = debounceIndex[key],
               let old = managedTasks.removeValue(forKey: oldID)
            {
                old.task.cancel()
            }
            debounceIndex[key] = id

        case .plain:
            break
        }

        managedTasks[id] = EffectTask(id: id, kind: kind, task: task)
        return id
    }

    private func finish(id: UUID, kind: ManagedKind) {
        _ = managedTasks.removeValue(forKey: id)

        switch kind {
        case let .replaceable(key):
            if replaceIndex[key] == id {
                replaceIndex[key] = nil
            }
        case let .debounce(key):
            if debounceIndex[key] == id {
                debounceIndex[key] = nil
            }
        case .plain:
            break
        }
    }
}
