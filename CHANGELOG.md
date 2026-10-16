# Changelog

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
