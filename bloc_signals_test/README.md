# bloc_signals_test

Declarative unit testing utilities for [`bloc_signals`](https://pub.dev/packages/bloc_signals) and `CubitSignal` instances.

`bloc_signals_test` provides `blocSignalTest`, a declarative helper (similar to `bloc_test`) tailored specifically for synchronous reactive signal state propagation and state de-duplication.

## Usage

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
  });

  group('CounterBloc', () {
    blocSignalTest<CounterBloc, int>(
      'emits [1] when IncrementEvent is added',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(IncrementEvent()),
      expect: () => [1],
    );
  });
}
```

## Features

- **Declarative assertions**: Verify emitted states in order using `expect`.
- **Async support**: Await asynchronous event handlers or timers with `wait`.
- **State skipping**: Skip initial emissions using `skip`.
- **Error testing**: Verify exceptions caught in `onError` using `errors`.
- **Automatic cleanup**: Guarantees signal subscriptions and `bloc.close()` are disposed post-test.
