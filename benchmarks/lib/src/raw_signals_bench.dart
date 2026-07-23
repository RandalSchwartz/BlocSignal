import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:signals_core/signals_core.dart';

/// Measures throughput for raw Signals primitive state updates.
class RawSignalThroughputBenchmark extends BenchmarkBase {
  /// Creates a [RawSignalThroughputBenchmark].
  RawSignalThroughputBenchmark() : super('RawSignal.value');

  /// Active signal instance.
  late Signal<int> countSignal;

  @override
  void setup() {
    countSignal = signal(0);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      countSignal.value = countSignal.value + 1;
    }
  }

  @override
  void teardown() {
    // Primitive cleanup if any
  }
}
