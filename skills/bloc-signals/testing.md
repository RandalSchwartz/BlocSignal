# BlocSignal Testing Guidelines

Because state propagation in `BlocSignal` is **immediate and synchronous**, testing state changes is much simpler and more deterministic than standard stream-based BLoCs.

---

## 📦 Declarative Testing with `bloc_signals_test`

The `bloc_signals_test` package provides the declarative `blocSignalTest` helper (similar to `bloc_test` in `flutter_bloc`) designed specifically for `BlocSignal` and `CubitSignal`:

```dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1] when increment is called',
      build: CounterCubit.new,
      act: (cubit) => cubit.increment(),
      expect: () => [1],
    );

    blocSignalTest<CounterCubit, int>(
      'supports skip parameter',
      build: CounterCubit.new,
      act: (cubit) {
        cubit.increment();
        cubit.increment();
      },
      skip: 1,
      expect: () => [2],
    );
  });

  group('CounterBloc', () {
    blocSignalTest<CounterBloc, int>(
      'emits [1] when IncrementEvent is added',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(IncrementEvent()),
      expect: () => [1],
    );

    blocSignalTest<CounterBloc, int>(
      'supports async event handler with wait parameter',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(DelayedIncrementEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [1],
    );
  });
}
```

---


## ⚡ Synchronous Testing

For synchronous event handlers, you do not need to use `expectLater`, streams, or async/await blocks. Assertions can be written directly on the next line of code:

```dart
import 'package:test/test.dart';
import 'my_counter_bloc.dart';

void main() {
  group('CounterBloc Sync Tests', () {
    test('initial state is correct', () {
      final bloc = CounterBloc();
      expect(bloc.stateValue, equals(0));
      bloc.close(); // Clean up lifecycle
    });

    test('handles event and updates state synchronously', () {
      final bloc = CounterBloc();
      
      bloc.add(Increment());
      expect(bloc.stateValue, equals(1));
      
      bloc.add(Decrement());
      expect(bloc.stateValue, equals(0));
      
      bloc.close();
    });
  });
}
```

---

## ⏳ Asynchronous Testing

For events that trigger asynchronous logic (e.g., calling network APIs), you have two options depending on how you trigger the event:

### Option A: Awaiting `onEvent` Directly
If you want to await the completion of all asynchronous event execution, call `onEvent(event)` directly and `await` it. `BlocSignal` coordinates event handler futures concurrently:

```dart
test('handles async fetch event', () async {
  final bloc = DataBloc(repository: mockRepo);

  // Directly await the event execution
  await bloc.onEvent(FetchDataEvent());

  expect(bloc.stateValue, isA<DataSuccess>());
  bloc.close();
});
```

### Option B: Using delays/timers
If calling `.add(event)` asynchronously (which triggers the zoned microtask chain), wait for the tick using standard async-testing tools:

```dart
test('handles async load event via add()', () async {
  final bloc = DataBloc(repository: mockRepo);

  bloc.add(FetchDataEvent());
  
  // Wait for async handler completion (adjust duration as needed)
  await Future<void>.delayed(const Duration(milliseconds: 10));

  expect(bloc.stateValue, isA<DataSuccess>());
  bloc.close();
});
```

---

## 🧪 Testing Mutator & Async Coordination Patterns

Both the **Completer Pattern** and the **AsyncSignal Pattern** are highly testable without requiring flaky delays or manual timeouts.

### 1. Testing the Completer Pattern
Because the `Completer` is passed directly in the event, you can await the completion of the future directly in your unit test assertions:

```dart
test('LoginSubmitted completes when login succeeds', () async {
  final bloc = AuthBloc(api: mockApi);
  final completer = Completer<void>();

  bloc.add(LoginSubmitted(
    email: 'user@example.com',
    password: 'password123',
    completer: completer,
  ));

  // Await the completer's future directly!
  await expectLater(completer.future, completes);
  expect(bloc.stateValue, isA<AuthSuccess>());
  bloc.close();
});

test('LoginSubmitted completes with error when login fails', () async {
  final bloc = AuthBloc(api: mockApi);
  final completer = Completer<void>();

  bloc.add(LoginSubmitted(
    email: 'user@example.com',
    password: 'wrong_password',
    completer: completer,
  ));

  // Verify the future throws the expected exception
  await expectLater(completer.future, throwsA(isA<AuthException>()));
  expect(bloc.stateValue, isA<AuthFailure>());
  bloc.close();
});
```

### 2. Testing the AsyncSignal (Mutation) Pattern
For direct method controllers tracking side-effects via a standalone `AsyncSignal`, you can await the controller action itself, or await the signal's internal `.future` property:

```dart
test('addTodo updates mutation signal states', () async {
  final controller = TodoController(api: mockApi);
  
  // 1. Initial State should be idle/data
  expect(controller.addTodoMutation.value.isLoading, isFalse);
  
  // 2. Execute and await the async call
  await controller.addTodo(Todo('New Task'));
  
  // 3. Verify it completed successfully
  expect(controller.addTodoMutation.value.hasError, isFalse);
  expect(controller.addTodoMutation.value.isLoading, isFalse);
});

test('awaiting addTodoMutation.future completes', () async {
  final controller = TodoController(api: mockApi);
  
  // Start the operation (dont await yet)
  final action = controller.addTodo(Todo('New Task'));
  
  // You can await the signal's internal future getter
  await expectLater(controller.addTodoMutation.future, completes);
  await action;
});
```

---

## 🛡️ Testing Rules & Best Practices

1. **Always Call `bloc.close()`**: To prevent memory leaks of underlying `SignalModel` tracking, always invoke `close()` on your blocs inside the test body or in a `tearDown()` block.
2. **De-duplication Expectations**: Remember that `emit()` de-duplicates values. If you dispatch an event that emits a state equal (`==`) to the current state, observers and listeners will **not** trigger. Keep this in mind when writing test verification assertions.

