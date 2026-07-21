# Migrating from classic BLoC

This workflow covers migrations from `package:bloc` and `package:flutter_bloc` to
`bloc_signals` and `bloc_signals_flutter`. The comparison notes were checked against `bloc` 9.2.1,
`bloc_signals` 0.1.13, and `bloc_signals_flutter` 0.1.9. Inspect the versions installed by the target
project before applying them.

## Decide whether to migrate

Inventory the current dependency and API surface:

```bash
rg -n "package:(bloc|flutter_bloc)/|BlocProvider|MultiBlocProvider|BlocBuilder|BlocListener|BlocConsumer|BlocSelector|RepositoryProvider|buildWhen|listenWhen|transformEvents|EventTransformer|emit\.(forEach|onEach)|\.stream\b" lib test
```

A mechanical migration is unsafe when the feature depends on event transformers, state streams,
listener or builder predicates, repository providers, or generated extensions around classic
BLoC. Design replacements and tests before changing imports.

## API map

| Classic BLoC | BlocSignal | Migration note |
| --- | --- | --- |
| `Bloc<Event, State>` | `BlocSignal<Event, State>` | Pass `initialState:` to `super`. |
| `Cubit<State>` | `CubitSignal<State>` | Keep public methods that call `emit`. |
| `state` value | `stateValue` | `state` is a `ReadonlySignal<State>`. |
| `BlocProvider(create:)` | `BlocSignalProvider(create:)` | Provider owns and closes the bloc. |
| `BlocProvider.value` | `BlocSignalProvider.value` | External owner keeps disposal. |
| `MultiBlocProvider` | `MultiBlocSignalProvider` | Provider entries need placeholder children. |
| `BlocBuilder` | `BlocSignalBuilder` | No `buildWhen` parameter. |
| `BlocListener` | `BlocSignalListener` | Runs immediately, exposes current state only, and has no `listenWhen`. |
| `BlocConsumer` | `BlocSignalConsumer` | Inherits listener behavior and has no `buildWhen`. |
| `BlocSelector` | `BlocSignalSelector` | Rebuilds when the selected value changes by equality. |
| `context.read<T>()` | `context.read<T>()` | Extension name is the same. |
| `context.watch<T>().state` | `BlocSignalBuilder` or a signals widget | BlocSignal `watch` tracks provider replacement only. |
| `BlocObserver` | `BlocSignalObserver` | Hook signatures and transition data differ. |

There is no direct package equivalent for `RepositoryProvider`, event transformers, `emit.forEach`,
`emit.onEach`, or a bloc state stream. The listener, consumer, and selector widgets are close
mappings, but they do not reproduce classic predicates or listener timing.

## State container conversion

Before:

```dart
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
  }
}
```

After:

```dart
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
  }
}
```

Keep an `onEvent` switch instead when sealed-event exhaustiveness is important.

For a method-driven cubit:

```dart
final class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}
```

## Semantic differences to test

### Scheduling

Classic BLoC processes added events through its stream pipeline. BlocSignal invokes synchronous
handlers inside `add`, so dependent code can observe the new state before `add` returns. Async
handlers still continue later, and callers cannot await `add`.

Audit code that assumes a microtask boundary, queues several events, or relies on transformer
ordering.

### Equality

Current classic BLoC also skips a state equal to the current state after its first emission.
BlocSignal always skips an equal state, including the first attempted emission of the initial
value. Do not claim that ordinary repeated-state de-duplication is unique to BlocSignal.

### Closure

Classic BLoC throws `StateError` when `emit` runs after close. BlocSignal asserts in debug mode and
returns without changing state in release mode. Both keep the last state readable.

### Observation

BlocSignal reports the new state and the zone-correlated event, not classic BLoC's `Transition`
object. Rework log formatting and telemetry tests.

## Flutter conversion

Before:

```dart
BlocProvider(
  create: (_) => CounterBloc(),
  child: BlocBuilder<CounterBloc, int>(
    builder: (context, count) => Text('$count'),
  ),
)
```

After:

```dart
BlocSignalProvider<CounterBloc>(
  create: (_) => CounterBloc(),
  child: BlocSignalBuilder<CounterBloc, int>(
    builder: (context, count) => Text('$count'),
  ),
)
```

Replace listeners and selectors only after checking their timing and predicates.
`BlocSignalListener` and the listener side of `BlocSignalConsumer` run once with the initial state.
In 0.1.9, an unrelated parent rebuild can also restart the internal effect and invoke the callback
again. Classic `BlocListener` does neither by default. Suppress the first or repeated callback when
needed, and recreate `listenWhen` or `buildWhen` explicitly.

`BlocSignalSelector` is the closest `BlocSelector` mapping when the selected value has meaningful
equality. Use manually owned signal primitives only for behavior the package widgets cannot
express. Those primitives require direct `signals` and `signals_flutter` dependencies and imports.
Never create a reaction in `build`, and dispose every manually owned reaction.

## Ordered migration

1. Add `bloc_signals`; add `bloc_signals_flutter` only for Flutter bindings.
2. Record focused tests for current event ordering, equality, errors, listeners, and disposal.
3. Convert one state container and its tests without changing behavior at the same time.
4. Replace provider ownership and state-aware widgets for that feature.
5. Redesign unsupported transformers, widget predicates, and stream consumers explicitly.
6. Remove classic BLoC dependencies only after searches show no imports or generated references.
7. Format, analyze, run focused tests, then run the feature or repository suite.

Keep the change reversible until the focused tests pass. If an unsupported stream behavior has no
agreed replacement, stop and report that migration boundary instead of hiding it behind timers or
an unowned effect.
