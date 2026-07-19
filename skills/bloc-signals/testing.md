# BlocSignal Testing Guidelines

Because state propagation in `BlocSignal` is **immediate and synchronous**, testing state changes is much simpler and more deterministic than standard stream-based BLoCs.

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

## 🛡️ Testing Rules & Best Practices

1. **Always Call `bloc.close()`**: To prevent memory leaks of underlying `SignalModel` tracking, always invoke `close()` on your blocs inside the test body or in a `tearDown()` block.
2. **De-duplication Expectations**: Remember that `emit()` de-duplicates values. If you dispatch an event that emits a state equal (`==`) to the current state, observers and listeners will **not** trigger. Keep this in mind when writing test verification assertions.
