# Core API and event processing

This reference matches `bloc_signals` 1.3.x. Re-read the installed source when the project uses a
different version.

## Public state and lifecycle

`BlocSignalBase<State>` owns state, effects registered through `createEffect`, observer hooks, and
closure. `CubitSignal<State>` adds no dispatch API; subclasses expose methods that call `emit`.
`BlocSignal<Event, State>` adds `add`, `on<E>`, and `onEvent` routing.

| API | Behavior |
| --- | --- |
| `value` | Reads the current `StateType` synchronously (preferred modern getter). |
| `stateValue` | Reads the current `StateType` synchronously (permanent alias for backward compatibility). |
| `state` | Exposes `ReadonlySignal<StateType>` for signals consumers. |
| `emit(next)` | Updates presentation state synchronously unless `next == stateValue`. |
| `emitError(error, [stackTrace])` | Emits an operational error to observers and container hooks (`addError` is a backward-compatible alias). |
| `emitTelemetry(name, {event, metadata})` | Emits an operational telemetry event and optional metadata payload to observers. |
| `BlocSignal.add(event)` | Routes an event and returns `void`. |
| `BlocSignalBase(..., options: ...)` | Accepts optional `SignalOptions<StateType>` to configure signal settings (such as debug `name`). Defaults debug name to `'$runtimeType.state'`. |
| `createEffect(callback, options: ..., onDispose: ...)` | Creates an effect immediately, assigning `options?.name` (defaulting to `'$runtimeType.effect#N'`) and registering its disposer with the base. |
| `isClosed` | Reports whether `close()` has run. |
| `close()` | Returns `Future<void>`, disposes registered effects and the internal `SignalModel`, and is idempotent. |
| `toString()` | Overridden by `BlocSignalBase` to output `'$runtimeType($stateValue)'`, providing immediate diagnostic visibility across all `CubitSignal` and `BlocSignal` subclasses. |
| `signal.toBlocSignal()` | Adapts any `ReadonlySignal<T>` (including `Signal`, `Computed`, `StreamSignal`, and `value.$`) into a `SignalBlocSignal<T>`. |
| `future.toBlocSignal(required initialState:)` | Adapts any `Future<T>` into a `FutureBlocSignal<T>` holding raw values with an initial state. |
| `future.toAsyncBlocSignal()` | Adapts any `Future<T>` into a `SignalBlocSignal<AsyncState<T>>` container backed by a `FutureSignal`. |
| `stream.toAsyncBlocSignal()` | Adapts any `Stream<T>` into a `SignalBlocSignal<AsyncState<T>>` container backed by a `StreamSignal`. |

### The Diagnostic Triad (`emit`, `emitError`, `emitTelemetry`)

`BlocSignalBase` structures application state, failure modes, and operational observability into three distinct, dedicated diagnostic primitives:

1. **`emit(state)`**: Exclusively models **presentation state** driving UI and computed derivations. Updates propagate synchronously in the same frame.
2. **`emitError(error, [stackTrace])`**: Models **exceptional operational failures** (for example API timeouts or unhandled parser failures) notifying `onError` on the container and global observers without corrupting presentation state. (Aliased by `addError` for classic BLoC compatibility).
3. **`emitTelemetry(name, [metadata])`**: Models **operational telemetry and business intent** (for example cache hits/misses, analytics milestones, concurrency events). Telemetry flows to `BlocSignalObserver.onTelemetry` without causing UI widget rebuilds. Built-in concurrency transformers automatically emit standardized keys via `BlocTelemetryKeys` (`eventDropped`, `taskPreempted`, `taskCanceled`, `eventQueued`). Standard telemetry calls short-circuit with zero allocations when no global observer is installed.

The state remains readable after closure. `add` silently drops new events. `emit` has a debug
assertion and then returns without changing state when assertions are disabled.

> [!NOTE]
> **Key Differences for Developers Migrating from Felix BLoC (`package:bloc`)**:
> - **Named Initial State**: Constructors take required named argument `initialState:` (`: super(initialState: ...)`), NOT positional `super(...)`.
> - **State Access**: Use `stateValue` (or `state.value`) to read raw `StateType` values inside methods/handlers (`emit(stateValue + 1)`). `state` returns `ReadonlySignal<StateType>` for reactive signal observers.

### Prefer Inline `late final` Computed Properties

When exposing derived, observable state properties on a `CubitSignal` or `BlocSignal`, **prefer declaring and initializing them directly as fields using type inference** instead of splitting them into a manual type declaration and constructor-body assignment:

```dart
class CartCubit extends CubitSignal<CartState> {
  CartCubit() : super(initialState: CartState.empty());

  // PREFERRED: Direct inline field initialization with type inference
  late final itemCount = computed(() => stateValue.items.length);
  late final totalPrice = computed(
    () => stateValue.items.fold(0.0, (sum, item) => sum + item.price),
  );
  late final isEmpty = computed(() => stateValue.items.isEmpty);
}
```

**Why this is preferred**:
- **Type Inference**: Dart infers `ReadonlySignal<T>` automatically without verbose type repetition.
- **Clean Constructors**: Keeps constructor parameter lists and bodies focused purely on initialization (`: super(initialState: ...)`).
- **Encapsulation**: Keeps the derivation rule right next to the property name on a single declarative line.

### Atomic State Transitions & Explicit Helper Emission Naming

In `CubitSignal` and `BlocSignal`, state transitions propagate synchronously and immediately in the exact same frame. Every emission represents an atomic state transition ($S_n \to S_{n+1}$).

1. **Explicit Helper Naming ("Does What It Says on the Tin")**:
   When factoring out complex state mutations or computations into private helper methods, any helper that calls `emit()` internally must declare this side-effect in its name (for example, `void _pruneAndEmit()` or `void _emitPosition()`, rather than an innocent-sounding `void _prune()`). This prevents callers from unwittingly triggering unexpected UI rebuilds and reactive observer runs.
   - Enforced by lint rule `require_emit_in_helper_name` with automated quick-fix `RequireEmitInHelperNameFix`.

2. **Avoid Multiple Synchronous Emits (State Atomicity)**:
   Avoid calling `emit()` multiple times along the same synchronous linear control-flow path without an intervening `await` or event loop boundary. Emitting multiple intermediate states in the same frame leaks temporary, inconsistent states to downstream subscribers and computed signals before the final state is reached.
   - Enforced by lint rule `avoid_multiple_synchronous_emits`.

```dart
// BAD: Innocent-sounding helper hides emit; multiple synchronous emits in one path
void updateCoordinates(Position pos) {
  emit(stateValue.add(pos)); // ⚠️ Emits intermediate unpruned state!
  _prune();                  // ⚠️ Helper emits again in the exact same frame!
}

void _prune() {
  emit(stateValue.where(...).toIList());
}

// GOOD: Single atomic jump; helper explicitly declares state emission
void updateCoordinates(Position pos) {
  _pruneAndEmit(base: stateValue.add(pos)); // Atomic single frame transition
}

void _pruneAndEmit({IList? base}) {
  final list = base ?? stateValue;
  emit(list.where(...).toIList());
}
```

### Frame Budget Defense (Isolate Moat, Batch Shield, Cooperative Time-Slice)

Because state transitions propagate synchronously within the same frame, heavy compute operations or tight event loops must not block the UI isolate. Always defend Flutter's frame budget (16.6ms for 60 FPS / 8.3ms for 120 FPS):

1. **The Isolate Moat (`Isolate.run`)**: Offload CPU-heavy parsing, cryptography, and large data sorting completely off the main isolate using `await Isolate.run(() => ...)`.
2. **The Batch Shield (`batch`)**: Collapse multiple independent signal or property mutations into a single frame paint using `batch(() => ...)`.
3. **The Cooperative Time-Slice (`Stopwatch` + `Future.pause` / `Future.delayed`)**: When processing massive collections that must stay on the main isolate, time-slice cooperatively by monitoring actual elapsed frame time (yielding with `await Future.pause()` in Dart 3.13+ or `await Future<void>.delayed(Duration.zero)` in Dart 3.5 when elapsed time exceeds 8ms).

*(For detailed architectural recipes and code comparisons, see [flutter.md](flutter.md#frame-budget-defense--preventing-ui-jank-60120-fps)).*

## Composable Mixins (Overcoming Single Inheritance)

In Dart, classes are restricted to single inheritance (`extends SuperClass`). When an existing class already extends a third-party or Flutter framework base class (for example `ChangeNotifier`, `TextEditingController`, `AnimationController`, or `BaseRepository`), use `CubitSignalMixin` and `BlocSignalMixin` to grant it full `BlocSignalBase` reactive capabilities without occupying its single inheritance slot:

### 1. CubitSignalMixin (Method-Driven Composable State)
```dart
class UserProfileRepository extends BaseRepository
    with CubitSignalMixin<UserProfileState> {
  UserProfileRepository() {
    initCubitSignal(initialState: const UserProfileInitial());
  }

  Future<void> fetchProfile(String id) async {
    emit(const UserProfileLoading());
    final user = await api.getUser(id);
    emit(UserProfileLoaded(user));
  }
}
```

### 2. BlocSignalMixin (Event-Driven Composable State)
```dart
class AuthenticationBlocService extends BaseService
    with
        CubitSignalMixin<AuthState>,
        BlocSignalMixin<AuthEvent, AuthState> {
  AuthenticationBlocService() {
    initCubitSignal(initialState: const AuthInitial());

    on<LoginRequested>((event, emit) async {
      emit(const AuthLoading());
      final user = await authApi.login(event.username, event.password);
      emit(AuthAuthenticated(user));
    });

    on<LogoutRequested>((event, emit) {
      emit(const AuthUnauthenticated());
    });
  }
}
```

### 3. DRY Core Architecture
`CubitSignal<StateType>` and `BlocSignal<Event, StateType>` compose `CubitSignalMixin` and `BlocSignalMixin` as their single source of truth:
- `CubitSignal<StateType>` extends `BlocSignalBase<StateType>` with `CubitSignalMixin<StateType>`
- `BlocSignal<Event, StateType>` extends `BlocSignalBase<StateType>` with `CubitSignalMixin<StateType>`, `BlocSignalMixin<Event, StateType>`

> [!TIP]
> **Static Lint Enforcement**:
> `bloc_signals_lint` automatically enforces `initCubitSignal` and `initBlocSignal` constructor invocations via the `require_cubit_signal_mixin_init` lint rule with automated IDE quick-fixes (`Cmd+.` / `Alt+Enter`).

Because `CubitSignalMixin` implements `BlocSignalBase<StateType>`, any class mixing it in is polymorphically compatible with `BlocSignalProvider`, `context.select`, `blocSignalTest`, `bloc_signals_riverpod`, `bloc_signals_hydrate`, and `bloc_signals_replay`.

## Targeted Domain Mixins on Cubits & Blocs (Composing Business Logic)

While `CubitSignalMixin` provides base cubit capabilities to external classes, **Targeted Domain Mixins** (`mixin DomainRules on CubitSignal<DomainState>`) compose domain-specific business rules, computed projections, and calculations onto your state containers.

### Why Target Domain Mixins on `CubitSignal<State>`?
In complex enterprise applications (such as e-commerce checkout, financial portfolios, or multi-step wizards), business logic quickly balloons:
- Promo codes, tiered discounts, and coupon redemption
- Tax rules, VAT calculations, and regional surcharges
- Freight thresholds and dynamic shipping tiers

Inlining all calculations into a single `CubitSignal` turns it into an unwieldy god-object. Conversely, moving derived numbers directly into the state record forces tedious manual recalculations on every single `emit()`.

### The Solution: Targeted Reactive Mixins
By targeting the mixin `on CubitSignal<StateType>`, the mixin receives safe, typed access to `stateValue` while keeping domain logic 100% decoupled from storage (`HydratedMixin`) or time-travel history (`ReplayCubitMixin`):

```dart
mixin CartPricingMixin on CubitSignal<ShoppingCartState> {
  /// Base subtotal derived from line items
  late final subtotal = computed(() => stateValue.items.values.fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      ));

  /// Tiered shipping calculation based on subtotal threshold
  late final shippingFee = computed(() {
    if (subtotal.value == 0.0 || subtotal.value >= 50.0) return 0.0;
    return 5.99;
  });

  /// Synchronous grand total composing multiple signals
  late final grandTotal = computed(() =>
      (subtotal.value - discountAmount.value + shippingFee.value)
          .clamp(0.0, double.infinity));
}
```

### Write Once, Test Once
Because the domain mixin is constrained only by `on CubitSignal<ShoppingCartState>`, you can verify complex pricing rules against a minimal test harness Cubit without needing database mocks, disk storage, or UI widgets:

```dart
class TestCartCubit extends CubitSignal<ShoppingCartState>
    with CartPricingMixin {
  TestCartCubit() : super(initialState: ShoppingCartState.empty());
  void updateState(ShoppingCartState next) => emit(next);
}

test('applies tiered shipping threshold correctly', () {
  final cubit = TestCartCubit();
  expect(cubit.shippingFee.value, 0.0); // Empty cart

  cubit.updateState(cartWithItem(price: 25.0));
  expect(cubit.shippingFee.value, 5.99); // Under $50 threshold

  cubit.updateState(cartWithItem(price: 55.0));
  expect(cubit.shippingFee.value, 0.0); // Free shipping unlocked
});
```

## Custom Equality & Identity Comparison (`equals`)

By default, `BlocSignalBase` uses standard value equality (`previous == current`) to de-duplicate state emissions and prevent redundant reactive updates.

> [!NOTE]
> Precedence Rule: If a custom `SignalOptions(equality: ...)` is provided in `options:`, it takes precedence over the constructor `equals:` callback or subclass `equals()` override.

You can customize the change-definition strategy by overriding `equals` in your subclass, passing an `equals:` callback, or specifying `options: SignalOptions(equality: ...)`:

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

### Force Always-Emit Mode (`equals => false`)
To reproduce classic stream behaviors where every `emit()` call notifies observers (even if the emitted state is identical to the current state), override `equals` to return `false`:

```dart
final class AlwaysEmitBloc extends BlocSignal<CounterEvent, CounterState> {
  AlwaysEmitBloc(CounterState initial) : super(initialState: initial);

  @override
  bool equals(CounterState previous, CounterState current) => false; // Every emit notifies!
}
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

In `BlocSignal`, event transformers are **streamless higher-order functions** with the signature:
```dart
typedef EventTransformer<E, StateType> = FutureOr<void> Function(
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);
```

You can pass an optional `transformer` to `on<E>` to control async event execution:

```dart
on<SearchQuery>(
  (event, emit) async => emit(await api.search(event.query)),
  transformer: droppable(),
);
```

Available built-in transformers & concurrency utilities:
- `droppable()`: Drops incoming events if a handler for that event type is currently executing.
- `sequential()`: Queues incoming events in FIFO order using a `Mutex` lock.
- `restartable()`: Allows new incoming events to supersede previous in-flight handler executions.
- `Mutex`: A zero-dependency async lock (`protect(() => ...)`) for custom synchronization.

#### Writing Custom Event Transformers

Custom transformers wrap `handler(event, emit)` using standard Dart primitives without Rx stream pipelines:

```dart
/// Debounces event handling by [duration] using a Timer.
EventTransformer<E, S> debounce<E, S>(Duration duration) {
  Timer? timer;
  return (event, handler, emit) {
    timer?.cancel();
    timer = Timer(duration, () {
      final result = handler(event, emit);
      if (result is Future) {
        unawaited(result);
      }
    });
  };
}

/// Guards handler execution with a boolean predicate.
EventTransformer<E, S> filterEvents<E, S>(bool Function(E) predicate) {
  return (event, handler, emit) {
    if (predicate(event)) {
      return handler(event, emit);
    }
  };
}
```

#### Contextual Event Transformers (`BlocEventTransformer`)

Contextual transformers receive the host `bloc` instance as their first parameter:
```dart
typedef BlocEventTransformer<E, StateType> = FutureOr<void> Function(
  BlocSignalMixin<dynamic, StateType> bloc,
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);
```

Register contextual transformers directly on `on<E>` using `blocTransformer:`:
```dart
on<SearchQueryChanged>(
  _onSearchQueryChanged,
  blocTransformer: debounceWithTelemetry(const Duration(milliseconds: 300)),
);
```

Only one of `transformer:` or `blocTransformer:` may be provided to `on<E>`.

- **`toBlocTransformer()`**: Extension method on `EventTransformer` that lifts any standard 3-parameter transformer into a 4-parameter `BlocEventTransformer` that ignores the host bloc argument.
- **`withBloc(transformer)`**: Instance method on `BlocSignalMixin` that binds `this` as the first argument of a `BlocEventTransformer`, returning a standard 3-parameter `EventTransformer`.



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
typed local `onTransition` hook.

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

## State atomicity and batch() guidance

### 1. Inherent Atomicity of emit()
Inside an individual `BlocSignal` or `CubitSignal`, state updates are **strictly atomic by design**.
Each container manages a single underlying `Signal<StateType> _state`. Calling `emit(newState)`
assigns `_state.value = newState` in a single synchronous operation without any intermediate or
partial states. Wrapping an individual `emit()` inside `batch()` is redundant.

### 2. Anti-Pattern: Batching Synchronous Emits
Do NOT wrap multiple synchronous `emit()` calls inside `batch()` in an event handler or method:
```dart
// ❌ Anti-pattern: Swallows ProfileLoading in reactive UI
on<ResetAndInit>((event, emit) {
  batch(() {
    emit(ProfileLoading());
    emit(ProfileReady(user));
  });
});
```
`batch()` delays reactive graph evaluation until the batch callback completes, causing downstream
subscribers (`BlocSignalBuilder`, `context.select`, `computed`) to observe only the final state,
skipping intermediate states. Meanwhile, observer hooks (`onTransition`, `onChange`) still execute
for each emit, creating a mismatch between observer logs and the UI.
- If an intermediate state should not be observed, do not emit it—emit the final state directly.
- If an intermediate state represents an asynchronous step (for example `Loading` before an async fetch),
  the updates occur across an `await` boundary, which synchronous `batch()` cannot span anyway.

### 3. Valid Use Cases for batch()
- **Cross-Bloc Coordination**: When a single user action mutates multiple independent blocs or cubits
  (for example logging out while resetting carts and clearing caches), wrap the dispatches in
  `batch(() { authBloc.add(Logout()); cartBloc.add(Clear()); })`. This guarantees that any widget or
  `computed()` depending on multiple state containers evaluates only once with consistent states.
- **Internal Auxiliary Signals**: When a state container manages multiple internal raw `Signal` instances
  that feed into a `computed()` derivation or `createEffect`, batching writes to those auxiliary signals
  prevents duplicate derivation runs.

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
- `onError(BlocSignalBase<dynamic> bloc, error, stackTrace)` for reported failures;
- `onTelemetry(BlocSignalBase<dynamic> bloc, String name, {Object? event, Map<String, dynamic>? metadata})` for operational telemetry and concurrency diagnostics;
- `onClose(BlocSignalBase<dynamic> bloc)` after owned effects and the internal model are disposed.

There is no built-in observer chain. Write a composite observer when logging and telemetry must run
together. `onCreate` runs before the subclass constructor body and late fields are initialized, so
observers should not read subtype-specific fields there. Local `onTransition`, `onChange`,
`onError`, and `close` are annotated `@mustCallSuper`; keep the superclass call in overrides.

Await `close()` when completion or observer errors matter. The cleanup body runs
synchronously before the returned future completes, but callers should code to the `Future<void>`
contract.
