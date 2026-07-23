import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bloc_signals/bloc_signals.dart';

/// Counter event hierarchy for BlocSignal benchmarks.
sealed class CounterEvent {}

/// Increment event.
final class Increment extends CounterEvent {}

/// Counter BlocSignal implementation.
final class CounterBlocSignal extends BlocSignal<CounterEvent, int> {
  /// Creates a [CounterBlocSignal].
  CounterBlocSignal() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
  }
}

/// Counter CubitSignal implementation.
final class CounterCubitSignal extends CubitSignal<int> {
  /// Creates a [CounterCubitSignal].
  CounterCubitSignal() : super(initialState: 0);

  /// Increments state.
  void increment() => emit(stateValue + 1);
}

/// Measures throughput for BlocSignal event dispatches.
class BlocSignalThroughputBenchmark extends BenchmarkBase {
  /// Creates a [BlocSignalThroughputBenchmark].
  BlocSignalThroughputBenchmark() : super('BlocSignal.add');

  /// Active container instance.
  late CounterBlocSignal bloc;

  @override
  void setup() {
    bloc = CounterBlocSignal();
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      bloc.add(Increment());
    }
  }

  @override
  void teardown() {
    unawaited(bloc.close());
  }
}

/// Measures throughput for BlocSignal with active subscriber.
class BlocSignalWithListenerBenchmark extends BenchmarkBase {
  /// Creates a [BlocSignalWithListenerBenchmark].
  BlocSignalWithListenerBenchmark() : super('BlocSignal + Subscriber');

  /// Active container instance.
  late CounterBlocSignal bloc;
  late void Function() _disposeListener;

  @override
  void setup() {
    bloc = CounterBlocSignal();
    _disposeListener = bloc.state.subscribe((_) {});
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      bloc.add(Increment());
    }
  }

  @override
  void teardown() {
    _disposeListener();
    unawaited(bloc.close());
  }
}

/// Measures throughput for CubitSignal state emissions.
class CubitSignalThroughputBenchmark extends BenchmarkBase {
  /// Creates a [CubitSignalThroughputBenchmark].
  CubitSignalThroughputBenchmark() : super('CubitSignal.emit');

  /// Active container instance.
  late CounterCubitSignal cubit;

  @override
  void setup() {
    cubit = CounterCubitSignal();
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      cubit.increment();
    }
  }

  @override
  void teardown() {
    unawaited(cubit.close());
  }
}
