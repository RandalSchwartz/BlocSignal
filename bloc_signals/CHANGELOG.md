## 0.2.5

- Add universal DevTools telemetry observer (`DevToolsBlocSignalObserver`) broadcasting `bloc_signal.*` VM Service events.
- Add VM Service RPC extensions (`DevToolsService`):
  - Register `ext.bloc_signal.getInstances` returning active container metadata and state values.
  - Register `ext.bloc_signal.getHistory` returning transition and error history entries per container.
  - Register `ext.bloc_signal.dispatch` enabling remote event dispatching over VM Service RPC.

## 0.2.4

- Add overridable change-definition (equality/identity) mechanism to state containers:
  - Add `@protected bool equals(StateType previous, StateType current)` method to `BlocSignalBase`.
  - Add optional `equals:` constructor parameter to `BlocSignalBase`, `CubitSignal`, and `BlocSignal`.
  - Add optional `equals:` parameter to `Stream.toBlocSignal()` extension.
  - Automatically synchronize custom equality rules with the underlying `state` (`ReadonlySignal`) graph.

## 0.2.3

- Add event concurrency strategy transformers and Mutex lock:
  - Add optional `transformer` parameter to `on<E>` event handler registry.
  - Add `droppable()`, `sequential()`, and `restartable()` event transformers.
  - Add zero-dependency `Mutex` class for FIFO queue async mutual exclusion.

## 0.2.2

- Add bidirectional stream interop extensions and progressive migration bridge:
  - Add `BlocSignalStreamExtension` on `BlocSignalBase` (`.toStream()`, `.stream`).
  - Add `StreamBlocSignal` container adapting standard Dart `Stream<T>` / BLoCs to `BlocSignalBase<T>`.
  - Add `StreamBlocSignalExtension` on `Stream<T>` (`.toBlocSignal()`).
  - Auto-close `StreamBlocSignal` when underlying stream completes.

## 0.2.1

- Fix package classification on pub.dev to include "Dart" SDK support by migrating from `signals` dependency to pure Dart `signals_core`.

## 0.2.0

- Introduce complete BLoC API Parity:
  - Add `Change` class for tracking state updates.
  - Add `Transition` class for tracking event-triggered state changes.
  - Add `onCreate`, `onChange`, and `onClose` observer methods to `BlocSignalObserver`.
  - Add `onChange` and `onTransition` local overrides.
  - Change `close()` to return `Future<void>`.

## 0.1.13

- Add `createEffect` helper to `BlocSignalBase` to support auto-disposed effects in subclass constructors.

## 0.1.12

- Simplify duplicate handler registration check in `on<E>` to throw `StateError` directly and resolve a test coverage gap.

## 0.1.11

- Refactor framework architecture to extract `BlocSignalBase` and introduce `CubitSignal` for clean, method-driven state management.
- Remove legacy `<void, State>` generic typing from Cubits.

## 0.1.10

- Remove pre-release Dart SDK constraints in favor of stable `^3.10.0`.
- Update documentation and structure the primary BLoC-to-BlocSignal migration guide inside a consumable AI coding assistant skill.

## 0.1.9

- Widen Dart SDK constraint to include pre-release versions of Dart `3.10.0`.

## 0.1.8

- Relax Dart SDK constraints to `^3.10.0` and relax `meta` package version constraints.

## 0.1.7

- Add BLoC-compatible `on<Event>` API handler registration registry.

## 0.1.6

- Fix relative Migration Guide link in README for pub.dev.

## 0.1.5

- Add assertion to throw `AssertionError` in debug/development mode when `emit()` is called after `close()`.

## 0.1.4

- Fix runtime TypeError when async `onEvent` returns a non-nullable Future type.

## 0.1.3

- Support asynchronous `onEvent` handlers (`FutureOr<void>`).
- Implement zone-based transition event context tracing.

## 0.1.2

- Implement `isClosed` and drop events/state updates after disposal.

## 0.1.1

- Add Cubit migration guide to documentation.

## 0.1.0

- Initial release of core `bloc_signals` state management primitives.
- Integrates Rody Davis's `signals` package with BLoC design patterns.
