# Testing BlocSignal Code

Use direct assertions for synchronous handlers, `blocSignalTest` from `package:bloc_signals_test` for declarative test suites, and deterministic completion signals for async handlers. Always close Blocs created by a test.

---

## Declarative Testing with `package:bloc_signals_test`

`package:bloc_signals_test` provides `blocSignalTest<B, S>` for declarative, isolated unit testing. It mirrors the familiar `blocTest` API from `package:bloc_test` with zero microtask queue latency.

```dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1] when increment is called',
      build: () => CounterCubit(),
      act: (cubit) => cubit.increment(),
      expect: () => [1],
    );

    blocSignalTest<CounterCubit, int>(
      'supports state seeding directly in constructor',
      build: () => CounterCubit(initialState: 10),
      act: (cubit) => cubit.increment(),
      expect: () => [11],
    );
  });
}
```

### Key Declarative Testing Guidelines
* **Observer Setup Timing**: `blocSignalTest` automatically sets up `BlocSignalObserver.observer` **before** invoking `build()` so `onCreate` lifecycle events are captured cleanly.
* **Automatic De-duplication**: `BlocSignal` automatically suppresses duplicate state emissions using `==` equality. Re-emitting an identical state will not produce a test emission.
* **Exceptions & Error Routing**: Use `errors: () => [isA<MyException>()]` to assert operational exceptions captured by `onError`.

---

## Synchronous Handlers & Direct Assertions

State changes finish before `add` or a Cubit method call returns:

```dart
test('increments synchronously', () {
  final bloc = CounterBloc();
  addTearDown(bloc.close);

  bloc.add(Increment());

  expect(bloc.stateValue, 1);
});
```

A repeated equal state must not produce `onTransition` or `onChange`.

Test a `CubitSignal` through its public methods. The state change is synchronous, and its observer transition has a null event because no `add` zone exists:

```dart
test('cubit command updates state', () {
  final cubit = CounterCubit();
  addTearDown(cubit.close);

  cubit.increment();

  expect(cubit.stateValue, 1);
});
```

### Diagnostic Output on Failure (`toString()`)
`BlocSignalBase` overrides `toString()` to output `$runtimeType($stateValue)` (for example, `CounterCubit(1)`). Failed test assertions print exact runtime state values rather than uninformative `Instance of 'CounterCubit'` logs.

---

## Streamless Concurrency Transformers

When testing event handlers using concurrency transformers (`droppable()`, `sequential()`, `restartable()`, `Mutex`), `BlocSignal` executes transformers synchronously or via pure Dart Futures without Rx streams or microtask lag:

```dart
blocSignalTest<CounterBloc, int>(
  'processes sequential events in order',
  build: () => CounterBloc(), // Uses on<Increment>(..., transformer: sequential())
  act: (bloc) {
    bloc.add(Increment());
    bloc.add(Increment());
  },
  expect: () => [1, 2],
);
```

---

## Async Handlers

`add` returns `void`, so a test cannot await it. Expose completion through the dependency under test, a `Completer`, or the emitted state. Avoid arbitrary delays when a deterministic seam exists.

```dart
test('emits data after the request completes', () async {
  final response = Completer<String>();
  final bloc = DataBloc(load: () => response.future);
  addTearDown(bloc.close);
  final ready = bloc.state
      .toStream()
      .firstWhere((state) => state == const Ready('ready'));

  bloc.add(LoadRequested());
  response.complete('ready');
  await expectLater(
    ready,
    completion(const Ready('ready')),
  );
});
```

Direct calls to `onEvent` bypass `BlocSignal.add`: no observer `onEvent`, event zone, close guard, or async error wrapper runs. Do not use direct calls as proof of dispatch behavior.

---

## Testing Satellite Packages (`hydrate` & `replay`)

### `bloc_signals_hydrate`
Test state persistence by mocking `HydratedStorage.storage`:

```dart
setUp(() {
  HydratedStorage.storage = MockHydratedStorage();
});

blocSignalTest<HydratedCounterCubit, int>(
  'restores persisted state on instantiation',
  build: () => HydratedCounterCubit(),
  act: (cubit) => cubit.increment(),
  verify: (cubit) {
    expect(HydratedStorage.storage.read('HydratedCounterCubit'), equals({'value': 1}));
  },
);
```

### `bloc_signals_replay`
Test undo/redo state history synchronously:

```dart
test('undoes state transition synchronously', () {
  final cubit = ReplayCounterCubit();
  addTearDown(cubit.close);

  cubit.increment(); // 1
  expect(cubit.stateValue, 1);

  cubit.undo(); // 0
  expect(cubit.stateValue, 0);
});
```

---

## Error Paths

Test operational exceptions and uncaught programmer errors:

```dart
final uncaught = Completer<Object>();
runZonedGuarded(
  () => bloc.add(FailWithError()),
  (error, stackTrace) {
    if (!uncaught.isCompleted) uncaught.complete(error);
  },
);

await expectLater(
  uncaught.future,
  completion(isA<ArgumentError>()),
);
```

Use an observer spy to verify error and event correlation. Reset `BlocSignalObserver.observer` in `tearDown` because it is global state.

---

## Closure & Lifecycle

Cover these lifecycle cases when ownership changes:

- `close` sets `isClosed` and is safe to call again.
- `close` returns a Future that tests await directly or through `addTearDown(bloc.close)`.
- `add` after close leaves state unchanged.
- post-close state remains readable.
- `emit` after close throws an assertion in debug tests.
- an effect registered through `createEffect` stops reacting after close.
- raw effects, computed values, subscriptions, and async work are disposed by their actual owner.
- a handler Future that already started is not treated as cancelled by `close`.

---

## Flutter Tests

State mutation is synchronous, but Flutter still needs a frame before rebuilt widgets appear:

```dart
bloc.add(Increment());
await tester.pump();
expect(find.text('1'), findsOneWidget);
```

For `BlocSignalProvider(create:)`, remove the provider from the tree and assert that the created bloc closes. For `.value`, assert that removal does not close the externally owned bloc. Test a missing provider as a `FlutterError` rather than adding a fallback.

For `BlocSignalListener` and `BlocSignalConsumer`, assert that mount does not call the listener, then emit a change and check the callback. Test `listenWhen` with a rejected and accepted change, an unrelated parent rebuild, unmount cleanup, and explicit bloc replacement.

---

## Test Discovery Configuration

Package entrypoint libraries ending in `_test.dart` (such as `package:bloc_signals_test`'s `lib/bloc_signals_test.dart`) match test runner globs when discovered recursively. To prevent test discovery failures, ensure `dart_test.yaml` is present specifying `paths: [test/]` to restrict test runner path matching strictly to `test/` directories.

---

## Validation Commands

Run non-UI core package unit tests (`bloc_signals`, `bloc_signals_test`, `bloc_signals_hydrate`, `bloc_signals_otel`, `bloc_signals_replay`) using `dart test` for sub-second CLI execution:

```bash
dart format <changed-files>
dart analyze <changed-path>
dart test <changed-test>
```

Use `flutter analyze` and `flutter test` for Flutter UI packages (`bloc_signals_flutter`).

