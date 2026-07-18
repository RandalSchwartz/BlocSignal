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
