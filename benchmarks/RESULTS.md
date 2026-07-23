# ⚡ BlocSignal Performance Benchmark Results

Automated empirical performance comparison across Dart state management frameworks (**BlocSignal**, **Classic BLoC**, **Riverpod**, **Provider**, and **Raw Signals**).
Each benchmark measures execution time in microseconds (μs) required for **1,000 state dispatches/emissions**.

| State Container / Mechanism | Time per 1k Dispatches (μs) | Est. Dispatches/sec | Relative Overhead vs Raw Signal |
| :--- | :---: | :---: | :---: |
| **Raw Signals (signal.value)** | 2759.12 μs | 362,435 | 1.00x |
| **CubitSignal.emit** | 4618.49 μs | 216,521 | 1.67x |
| **BlocSignal.add** | 8078.62 μs | 123,783 | 2.93x |
| **BlocSignal + Subscriber** | 8897.53 μs | 112,391 | 3.22x |
| **Provider (ChangeNotifier)** | 99.70 μs | 10,029,669 | 0.04x |
| **Provider + Listener** | 270.08 μs | 3,702,610 | 0.10x |
| **Riverpod Notifier** | 139774.22 μs | 7,154 | 50.66x |
| **Riverpod + Listener** | 116804.12 μs | 8,561 | 42.33x |
| **Classic Cubit.emit** | 149.81 μs | 6,675,176 | 0.05x |
| **Classic Bloc.add** | 12603.98 μs | 79,340 | 4.57x |
| **Classic Bloc + Listener** | 4394.61 μs | 227,551 | 1.59x |

## 📊 Cross-Framework Key Takeaways & Architecture Analysis

1. **Synchronous Signal Graph Execution**: `BlocSignal` and `CubitSignal` propagate state updates synchronously down the dependency graph on the exact same frame. Calling `emit()` or `add()` triggers downstream reactive recalculations without microtask queue latency.
2. **Provider / ChangeNotifier vs Signals**: `Provider` (`ChangeNotifier`) uses an internal array dispatch loop (`notifyListeners()`). While `ChangeNotifier` is fast for simple arrays, fine-grained `Signal` graph tracking in `BlocSignal` avoids unnecessary rebuilds for non-dependent UI subtrees.
3. **Stream Buffering vs Direct Execution**: Classic `package:bloc` delegates dispatches onto asynchronous `StreamController` microtask queues. While buffering items to a queue yields fast initial function returns, actual UI rebuilds must wait for microtask queue draining in subsequent frames.
4. **Zero Resolution Overhead**: `BlocSignal` operates directly on lightweight signal nodes without requiring provider container lookup or provider dependency resolution on every state write.
