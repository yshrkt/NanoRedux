# Changelog

## 0.2.0 - 2026-11-03

### Breaking Changes

- Replaced the concrete `Store` wrapper and internal `Storing` protocol with the public `Store<State, Action>` protocol. Use `StoreBuilder.reducer(...)` to create a root `ReducerStore`, and `any Store<State, Action>` when a shared root/scoped interface is needed. Scoped stores retain the same `state`, `send`, and `scope` API.
- Logging configuration is available only on root `ReducerStore` instances, before assigning them to `any Store`. Scoped stores do not expose `.logging()`.

### Migration

Replace both `Store.reducer(...)` and `Store<State, Action>.reducer(...)` with `StoreBuilder.reducer(...)`. Contextual `.reducer(...)` calls also need the explicit builder name:

```diff
- let store = Store.reducer(initialState: AppState(), reducer: AppReducer())
+ let store = StoreBuilder.reducer(initialState: AppState(), reducer: AppReducer())
```

Change explicit store annotations to the protocol's existential type. Inferred declarations such as `@State private var store = StoreBuilder.reducer(...)` need no additional annotation:

```diff
- @State private var store: Store<AppState, AppAction>
+ @State private var store: any Store<AppState, AppAction>

- var store: Store<AppState, AppAction>?
+ var store: (any Store<AppState, AppAction>)?
```

Apply the same annotation change to parameters and return types. Constrain protocol extensions using associated types:

```diff
- extension Store<AppState, AppAction> {
+ extension Store where State == AppState, Action == AppAction {
```

Configure `.logging(...)` on the root returned by `StoreBuilder.reducer(...)`, before assigning it to `any Store`. Scoped stores and the shared protocol do not expose logging configuration. Calls to `state`, `send`, and `scope` keep the same syntax.

### Added

- Root store `.logging([.action, .state], name: "App")` with an optional state-formatting closure. Logs include state at configuration time and after each processed action, including effect actions. Debug-only reflection stops at `_$` properties and handles cycles and traversal limits.

## 0.1.3 - 2026-10-16

### Breaking Changes

- Renamed `Effect.execute()` to `Effect.executeForTesting()`. The old method has been removed without an alias. Update direct calls:

  ```diff
  - let action = await effect.execute()
  + let action = await effect.executeForTesting()
  ```

  This unit-testing helper returns the last collected action but bypasses debounce/throttle scheduling and lifetime policies. Use Store-based tests to verify timing, replacement, and lifecycle behavior. The rename only affects direct calls, not Store-based execution.

### Changed

- Switched the Store action queue to unbounded buffering to prevent action loss during bursts.

### Fixed

- Propagated cancellation through `Effect.stream` and mapped streams to underlying subscriptions.
- Fixed `ReducerStore` retention while waiting for actions, allowing store-bound effects to be cancelled on teardown.
- Notified observers when State is replaced, including through scoped stores, while preserving property-level tracking for in-place reference-state updates.
- Stopped `executeForTesting()` from starting subsequent effects or collecting new actions after cancellation.

## [0.1.2](https://github.com/yshrkt/NanoRedux/releases/tag/0.1.2) - 2026-04-11

### Added

- `Effect.stream` for non-throwing, Sendable `AsyncSequence` sources, including `AsyncStream`, with action mapping through `Effect.map`.

## [0.1.1](https://github.com/yshrkt/NanoRedux/releases/tag/0.1.1) - 2026-04-03

### Added

- Chainable `Effect.concat(_:)` and `Effect.merge(_:)` instance methods, with flattening of nested compositions.

### Fixed

- Release-build compilation errors in `ReducerStore` teardown.

## [0.1.0](https://github.com/yshrkt/NanoRedux/releases/tag/0.1.0) - 2026-04-03

Initial release.
