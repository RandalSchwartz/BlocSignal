# Core API and event processing

This reference matches `bloc_signals` 0.1.10. Re-read the installed source when the project uses a
different version.

## Public state and lifecycle

| API | Behavior |
| --- | --- |
| `stateValue` | Reads the current `StateType` synchronously. |
| `state` | Exposes `ReadonlySignal<StateType>` for signals consumers. |
| `emit(next)` | Updates synchronously unless `next == stateValue`. |
| `add(event)` | Routes an event and returns `void`. |
| `isClosed` | Reports whether `close()` has run. |
| `close()` | Disposes the internal `SignalModel`; repeated calls do nothing. |

The state remains readable after closure. `add` silently drops new events. `emit` has a debug
assertion and then returns without changing state when assertions are disabled.

## Event routing

Choose one routing style per bloc.

Use `on<E>` for familiar event registration:

```dart
sealed class CounterEvent {}
final class Increment extends CounterEvent {}

final class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
  }
}
```

Registration checks duplicate exact types only while assertions are enabled. Matching uses `is E`,
so an event can match handlers registered for both a subtype and a supertype. Synchronous handlers
run in registry order. Returned futures are joined with `Future.wait` inside `onEvent`.

Override `onEvent` with an exhaustive switch when a sealed event hierarchy needs compile-time
coverage:

```dart
@override
void onEvent(CounterEvent event) {
  switch (event) {
    case Increment():
      emit(stateValue + 1);
  }
}
```

`add` calls the global observer, enters a zone that carries the current event, and invokes
`onEvent`. An async handler continues in that zone, so a later `emit` can still be correlated with
the event. An `emit` caused by another bloc does not borrow the wrong event because the zone value
must match that bloc's event type.

## Error behavior

| Failure | Result from `add` |
| --- | --- |
| Synchronous `Exception` | Calls `onError` and is swallowed. |
| Synchronous `Error` | Calls `onError` and rethrows to the caller. |
| Async `Exception` | Calls `onError` after the future fails and is swallowed. |
| Async `Error` | Calls `onError` and rethrows into the current zone. |

Do not treat `onError` as recovery. Put expected failures in state or another explicit result type.

## Equality

BlocSignal compares the current and next state with `==` before updating the signal or notifying
`onTransition`. Immutable state with meaningful equality is therefore part of the contract. A
mutable state object reused after in-place changes can suppress the update and hide changes from
consumers.

## Reactive ownership

`state` can feed `computed`, `effect`, or `subscribe`, but BlocSignal only disposes the internal
model created by its base constructor. An effect created later in a subclass constructor is not
automatically owned by `close()`.

Keep the returned disposer and release it from an overridden `close` method, or put related signals
inside an explicitly owned model:

```dart
late final void Function() _disposeLog;

CounterBloc() : super(initialState: 0) {
  _disposeLog = effect(() => print(stateValue));
}

@override
void close() {
  if (isClosed) return;
  _disposeLog();
  super.close();
}
```

Guard custom disposal with `isClosed` when it cannot safely run twice.

## Observers

`BlocSignalObserver.observer` is process-global. Its hooks receive:

- `onEvent(bloc, event)` before routing;
- `onTransition(bloc, event, state)` after a non-equal state update;
- `onError(bloc, error, stackTrace)` for event-processing failures.

There is no built-in observer chain. Write a composite observer when logging and telemetry must run
together.
