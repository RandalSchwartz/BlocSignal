import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:riverpod/riverpod.dart';

/// Counter Notifier for Riverpod benchmark.
final class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Increments state.
  void increment() => state = state + 1;
}

/// Riverpod counter provider definition.
final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);

/// Measures throughput for Riverpod state updates via ProviderContainer.
class RiverpodThroughputBenchmark extends BenchmarkBase {
  /// Creates a [RiverpodThroughputBenchmark].
  RiverpodThroughputBenchmark() : super('Riverpod.Notifier');

  /// Active container instance.
  late ProviderContainer container;

  @override
  void setup() {
    container = ProviderContainer();
  }

  @override
  void run() {
    final notifier = container.read(counterProvider.notifier);
    for (var i = 0; i < 1000; i++) {
      notifier.increment();
    }
  }

  @override
  void teardown() {
    container.dispose();
  }
}

/// Measures throughput for Riverpod with active container listener.
class RiverpodWithListenerBenchmark extends BenchmarkBase {
  /// Creates a [RiverpodWithListenerBenchmark].
  RiverpodWithListenerBenchmark() : super('Riverpod + Listener');

  /// Active container instance.
  late ProviderContainer container;
  late ProviderSubscription<int> sub;

  @override
  void setup() {
    container = ProviderContainer();
    sub = container.listen(counterProvider, (previous, next) {});
  }

  @override
  void run() {
    final notifier = container.read(counterProvider.notifier);
    for (var i = 0; i < 1000; i++) {
      notifier.increment();
    }
  }

  @override
  void teardown() {
    sub.close();
    container.dispose();
  }
}
