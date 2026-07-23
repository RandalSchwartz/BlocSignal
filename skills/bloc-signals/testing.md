# Testing BlocSignal code

Use direct assertions for synchronous handlers and deterministic completion signals for async
handlers. Always close blocs created by a test.

## Synchronous handlers

State changes finish before `add` returns:

```dart
test('increments synchronously', () {
  final bloc = CounterBloc();
  addTearDown(bloc.close);

  bloc.add(Increment());

  expect(bloc.stateValue, 1);
});
```

Also test equality suppression when observers or effects matter. A repeated equal state must not
produce `onTransition` or `onChange`.

Test a `CubitSignal` through its public methods. The state change is synchronous, and its observer
transition has a null event because no `add` zone exists:

```dart
test('cubit command updates state', () {
  final cubit = CounterCubit();
  addTearDown(cubit.close);

  cubit.increment();

  expect(cubit.stateValue, 1);
});
```

Constructing a bloc with duplicate `on<E>` registrations must throw `StateError` in every build
mode. When a test bloc overrides `onEvent`, keep the required `super.onEvent(event)` call.

For 0.2.0 lifecycle work, assert `Change.currentState` and `nextState`, plus the event and both
states in a typed `Transition`. Verify that local transition hooks run before `stateValue` changes,
local change hooks run after it, and both overrides call `super` so the global observer still sees
them. Observer tests should cover create, event, transition, change, error, and close, then reset the
global observer.

## Async handlers

`add` returns `void`, so a test cannot await it. Expose completion through the dependency under
test, a `Completer`, or the emitted state. Avoid arbitrary delays when a deterministic seam exists.

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

Verify `toStream()` exists in the installed `signals` version before using this exact helper. If it
does not, subscribe to `state`, complete a test-owned `Completer`, and dispose the subscription.

Calling `onEvent` directly can be useful for a narrow handler unit test, but it bypasses
`BlocSignal.add`: no observer `onEvent`, event zone, close guard, or async error wrapper runs. Do not
use a direct call as proof of dispatch behavior.

## Error paths

Test the four error cases described in [core.md](core.md). Async `Error` objects are rethrown into a
zone, so capture them with `runZonedGuarded`:

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

Use an observer spy to verify error and event correlation. Reset
`BlocSignalObserver.observer` in `tearDown` because it is global state.

## Closure

Cover these lifecycle cases when ownership changes:

- `close` sets `isClosed` and is safe to call again.
- `close` returns a future that tests await directly or through `addTearDown(bloc.close)`.
- `add` after close leaves state unchanged.
- post-close state remains readable.
- `emit` after close throws an assertion in debug tests.
- an effect registered through `createEffect` stops reacting after close.
- raw effects, computed values, subscriptions, and async work are disposed by their actual owner.
- a handler future that already started is not treated as cancelled by `close`.

## Flutter tests

State mutation is synchronous, but Flutter still needs a frame before rebuilt widgets appear:

```dart
bloc.add(Increment());
await tester.pump();
expect(find.text('1'), findsOneWidget);
```

For `BlocSignalProvider(create:)`, remove the provider from the tree and assert that the created
bloc closes. For `.value`, assert that removal does not close the externally owned bloc. Test a
missing provider as a `FlutterError` rather than adding a fallback.

For `BlocSignalListener` and `BlocSignalConsumer`, assert that mount does not call the listener,
then emit a change and check the callback. Test `listenWhen` with a rejected and accepted change,
an unrelated parent rebuild, unmount cleanup, and explicit bloc replacement. A replacement alone
does not emit its current state. If an omitted `bloc:` can be replaced through the provider, add a
focused test because direct listener lookup in 0.2.0 does not register that dependency.

Test lazy providers with zero factory calls before lookup, one call after lookup, eager construction
with `lazy: false`, and correct ownership on removal. Test every `MultiBlocSignalListener` callback.
For `BlocSignalSelector` and `context.select`, keep the selected value equal for one source change,
then change the selection; only the latter should rebuild. Keep multiple `context.select` calls in
a fixed order and test provider replacement if the feature permits it.

## Validation commands

Run the narrowest relevant commands first:

```bash
dart format <changed-files>
dart analyze <changed-path>
dart test <changed-test>
```

Use `flutter analyze` and `flutter test` for Flutter code. Follow broader repository gates when the
change affects shared APIs or release behavior.
