import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

/// Counter Cubit implementation for testing demonstration.
class CounterCubit extends CubitSignal<int> {
  /// Initializes [CounterCubit] with initial state 0.
  CounterCubit() : super(0);

  /// Increments state value.
  void increment() => emit(stateValue + 1);
}

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1] when increment is called',
      build: CounterCubit.new,
      act: (cubit) => cubit.increment(),
      expect: () => [1],
    );
  });
}
