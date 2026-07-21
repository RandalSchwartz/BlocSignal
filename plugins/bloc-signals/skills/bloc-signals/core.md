# Core API and event processing

This reference matches `bloc_signals` 0.1.13. Re-read the installed source when the project uses a
different version.

## Public state and lifecycle

`BlocSignalBase<State>` owns state, effects registered through `createEffect`, observer hooks, and
closure. `CubitSignal<State>` adds no dispatch API; subclasses expose methods that call `emit`.
`BlocSignal<Event, State>` adds `add`, `on<E>`, and `onEvent` routing.

| API | Behavior |
| --- | --- |
| `stateValue` | Reads the current `StateType` synchronously. |
| `state` | Exposes `ReadonlySignal<StateType>` for signals consumers. |
| `emit(next)` | Updates synchronously unless `next == stateValue`. |
| `BlocSignal.add(event)` | Routes an event and returns `void`. |
| `createEffect(callback, onDispose: ...)` | Creates an effect immediately and registers its disposer with the base. |
| `isClosed` | Reports whether `close()` has run. |
| `close()` | Disposes registered effects and the internal `SignalModel`; repeated calls do nothing. |

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

Registration throws `StateError` for a duplicate exact type in every build mode. Matching uses
`is E`, so an event can match handlers registered for both a subtype and a supertype. Synchronous
handlers run in registry order. Returned futures are joined with `Future.wait` inside `onEvent`.

Override `onEvent` with an exhaustive switch when a sealed event hierarchy needs compile-time
coverage:

```dart
@override
FutureOr<void> onEvent(CounterEvent event) {
  switch (event) {
    case Increment():
      emit(stateValue + 1);
  }
  return super.onEvent(event);
}
```

`onEvent` is annotated `@mustCallSuper`. Returning the superclass result preserves any registered
handler futures without making the synchronous switch asynchronous. Import `dart:async` for
`FutureOr`.

`add` calls the global observer, enters a zone that carries the current event, and invokes
`onEvent`. An async handler continues in that zone, so a later `emit` can still be correlated with
the event. Each state container has its own zone key, so an `emit` on another bloc does not borrow
the first bloc's event. A `CubitSignal` transition and any emit outside `add` report a null event.

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

Use `createEffect` for an effect owned by the state container. It runs immediately, returns its
disposer, and is disposed by `close`:

```dart
import 'package:signals/signals.dart';

final class MirrorCubit extends CubitSignal<int> {
  MirrorCubit(this.source) : super(initialState: source.value) {
    createEffect(() => emit(source.value));
  }

  final ReadonlySignal<int> source;
}
```

`close` marks the container closed before it runs effect disposal callbacks. Do not emit from an
`onDispose` callback. The emit will assert in debug mode and be dropped in release mode.

Raw `effect`, `computed`, subscriptions, timers, and async operations are not registered by
`createEffect`. Keep their owner and cleanup explicit. Override `close` when the container owns
such resources, and always call `super.close()`:

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

Closing a bloc does not cancel handler futures that already started. Cancel the underlying work
when possible, or check request freshness and `isClosed` after each async gap before emitting.

## Observers

`BlocSignalObserver.observer` is process-global. Its hooks receive:

- `onEvent(BlocSignalBase<dynamic> bloc, event)` before `BlocSignal` routing;
- `onTransition(BlocSignalBase<dynamic> bloc, event, state)` after a non-equal state update;
- `onError(BlocSignalBase<dynamic> bloc, error, stackTrace)` for reported failures.

There is no built-in observer chain. Write a composite observer when logging and telemetry must run
together. `onError` and `close` are also annotated `@mustCallSuper`; keep the superclass call in
overrides.
