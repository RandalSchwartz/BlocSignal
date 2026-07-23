import 'package:benchmark_harness/benchmark_harness.dart';

/// Counter ChangeNotifier implementation for Provider benchmarks.
class CounterChangeNotifier {
  int _count = 0;
  final List<void Function()> _listeners = [];

  /// Retrieves current count.
  int get count => _count;

  /// Registers a listener.
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Removes a listener.
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Increments count and notifies listeners.
  void increment() {
    _count++;
    notifyListeners();
  }

  /// Notifies all registered listeners.
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}

/// Measures throughput for ChangeNotifier state notifications.
class ProviderThroughputBenchmark extends BenchmarkBase {
  /// Creates a [ProviderThroughputBenchmark].
  ProviderThroughputBenchmark() : super('Provider (ChangeNotifier)');

  /// Active notifier instance.
  late CounterChangeNotifier notifier;

  @override
  void setup() {
    notifier = CounterChangeNotifier();
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      notifier.increment();
    }
  }
}

/// Measures throughput for Provider/ChangeNotifier with active listener.
class ProviderWithListenerBenchmark extends BenchmarkBase {
  /// Creates a [ProviderWithListenerBenchmark].
  ProviderWithListenerBenchmark() : super('Provider + Listener');

  /// Active notifier instance.
  late CounterChangeNotifier notifier;
  late void Function() _listener;

  @override
  void setup() {
    notifier = CounterChangeNotifier();
    _listener = () {};
    notifier.addListener(_listener);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      notifier.increment();
    }
  }

  @override
  void teardown() {
    notifier.removeListener(_listener);
  }
}
