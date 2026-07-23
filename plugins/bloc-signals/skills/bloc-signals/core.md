# Core API and event processing

This reference matches `bloc_signals` 0.2.0. Re-read the installed source when the project uses a
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
| `close()` | Returns `Future<void>`, disposes registered effects and the internal `SignalModel`, and is idempotent. |

The state remains readable after closure. `add` silently drops new events. `emit` has a debug
assertion and then returns without changing state when assertions are disabled.

## Custom Equality & Identity Comparison (`equals`)

By default, `BlocSignalBase` uses standard value equality (`previous == current`) to de-duplicate state emissions and prevent redundant reactive updates.

You can customize the change-definition strategy by overriding `equals` in your subclass or passing an `equals:` callback to the constructor:

### Subclass Override Example (Identity / Reference Equality)
```dart
final class IdentityCounterBloc extends BlocSignal<CounterEvent, CounterState> {
  IdentityCounterBloc(CounterState initial) : super(initialState: initial);

  @override
  bool equals(CounterState previous, CounterState current) {
    return identical(previous, current);
  }
}
```

### Constructor Callback Injection Example
```dart
final bloc = CounterBloc(
  initialState: CounterState(0),
  equals: (prev, next) => prev.id == next.id,
);
```

The underlying `state` signal (`ReadonlySignal`) automatically inherits the custom equality rules, ensuring downstream `SignalBuilder` widgets, `computed` derivations, and `effect` callbacks stay in 100% unified sync.

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

### Event Concurrency & Transformers

You can pass an optional `transformer` to `on<E>` to control async event execution:

```dart
on<SearchQuery>(
  (event, emit) async => emit(await api.search(event.query)),
  transformer: droppable(),
);
```

Available built-in transformers & concurrency utilities:
- `droppable()`: Drops incoming events if a handler for that event type is currently executing.
- `sequential()`: Queues incoming events in FIFO order using a [Mutex] lock.
- `restartable()`: Allows new incoming events to supersede previous in-flight handler executions.
- `Mutex`: A zero-dependency async lock (`protect(() => ...)`) for custom synchronization.


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
For a nullable event type, `add(null)` is also treated as a null-event transition and skips the
typed local `onTransition` hook in 0.2.0.

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

## Change and transition hooks

`Change<State>` records `currentState` and `nextState`. `Transition<Event, State>` adds the event.
Both are public immutable value objects with equality, `hashCode`, and `toString`.

For an event-backed `BlocSignal` emit, the typed local `onTransition(Transition<Event, State>)`
runs before state mutation. Its required `super.onTransition` call forwards the event and next
state to the global observer. The state signal then updates, followed by local
`onChange(Change<State>)`; its required superclass call forwards the change globally.

`CubitSignal` has no typed local transition hook. Its global transition carries a null event, then
its local and global change hooks run after mutation. Equal emits run none of these hooks. A thrown
transition callback prevents the write, while a thrown change callback happens after the write.

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
such resources, and always await `super.close()`:

```dart
late final void Function() _disposeLog;

CounterBloc() : super(initialState: 0) {
  _disposeLog = effect(() => print(stateValue));
}

@override
Future<void> close() async {
  if (isClosed) return;
  _disposeLog();
  await super.close();
}
```

Guard custom disposal with `isClosed` when it cannot safely run twice.

Closing a bloc does not cancel handler futures that already started. Cancel the underlying work
when possible, or check request freshness and `isClosed` after each async gap before emitting.

## Observers

`BlocSignalObserver.observer` is process-global. Its hooks receive:

- `onCreate(BlocSignalBase<dynamic> bloc)` from the base constructor;
- `onEvent(BlocSignalBase<dynamic> bloc, event)` before `BlocSignal` routing;
- `onTransition(BlocSignalBase<dynamic> bloc, event, nextState)` before an event-backed write, or
  with a null event for cubit and direct emits;
- `onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change)` after the state write;
- `onError(BlocSignalBase<dynamic> bloc, error, stackTrace)` for reported failures.
- `onClose(BlocSignalBase<dynamic> bloc)` after owned effects and the internal model are disposed.

There is no built-in observer chain. Write a composite observer when logging and telemetry must run
together. `onCreate` runs before the subclass constructor body and late fields are initialized, so
observers should not read subtype-specific fields there. Local `onTransition`, `onChange`,
`onError`, and `close` are annotated `@mustCallSuper`; keep the superclass call in overrides.

Await `close()` when completion or observer errors matter. The current 0.2.0 cleanup body runs
synchronously before the returned future completes, but callers should code to the `Future<void>`
contract.
