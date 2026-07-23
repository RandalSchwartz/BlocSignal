import 'dart:async';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bloc/bloc.dart' as classic;

/// Classic BLoC event hierarchy.
sealed class ClassicCounterEvent {}

/// Classic increment event.
final class ClassicIncrement extends ClassicCounterEvent {}

/// Classic Stream-based BLoC.
final class ClassicCounterBloc
    extends classic.Bloc<ClassicCounterEvent, int> {
  /// Creates a [ClassicCounterBloc].
  ClassicCounterBloc() : super(0) {
    on<ClassicIncrement>((event, emit) => emit(state + 1));
  }
}

/// Classic Cubit.
final class ClassicCounterCubit extends classic.Cubit<int> {
  /// Creates a [ClassicCounterCubit].
  ClassicCounterCubit() : super(0);

  /// Increments state.
  void increment() => emit(state + 1);
}

/// Measures throughput for classic Stream BLoC event dispatches.
class ClassicBlocThroughputBenchmark extends BenchmarkBase {
  /// Creates a [ClassicBlocThroughputBenchmark].
  ClassicBlocThroughputBenchmark() : super('ClassicBloc.add');

  /// Active container instance.
  late ClassicCounterBloc bloc;

  @override
  void setup() {
    bloc = ClassicCounterBloc();
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      bloc.add(ClassicIncrement());
    }
  }

  @override
  void teardown() {
    unawaited(bloc.close());
  }
}

/// Measures throughput for classic BLoC with active listener.
class ClassicBlocWithListenerBenchmark extends BenchmarkBase {
  /// Creates a [ClassicBlocWithListenerBenchmark].
  ClassicBlocWithListenerBenchmark() : super('ClassicBloc + Listener');

  /// Active container instance.
  late ClassicCounterBloc bloc;
  late StreamSubscription<int> sub;

  @override
  void setup() {
    bloc = ClassicCounterBloc();
    sub = bloc.stream.listen((_) {});
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      bloc.add(ClassicIncrement());
    }
  }

  @override
  void teardown() {
    unawaited(sub.cancel());
    unawaited(bloc.close());
  }
}

/// Measures true end-to-end throughput for classic BLoC with drained stream.
class ClassicBlocDrainedBenchmark extends AsyncBenchmarkBase {
  /// Creates a [ClassicBlocDrainedBenchmark].
  ClassicBlocDrainedBenchmark() : super('ClassicBloc (Drained Stream)');

  /// Active container instance.
  late ClassicCounterBloc bloc;

  @override
  Future<void> setup() async {
    bloc = ClassicCounterBloc();
  }

  @override
  Future<void> run() async {
    final streamDone = bloc.stream.take(1000).drain<void>();
    for (var i = 0; i < 1000; i++) {
      bloc.add(ClassicIncrement());
    }
    await streamDone;
  }

  @override
  Future<void> teardown() async {
    await bloc.close();
  }
}

/// Measures throughput for classic Cubit state emissions.
class ClassicCubitThroughputBenchmark extends BenchmarkBase {
  /// Creates a [ClassicCubitThroughputBenchmark].
  ClassicCubitThroughputBenchmark() : super('ClassicCubit.emit');

  /// Active container instance.
  late ClassicCounterCubit cubit;

  @override
  void setup() {
    cubit = ClassicCounterCubit();
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
