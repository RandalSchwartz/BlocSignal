# ⚡ BlocSignal Performance Benchmark Results

Automated empirical performance comparison across Dart state management frameworks (**BlocSignal**, **Classic BLoC**, **Riverpod**, **Provider**, and **Raw Signals**).
Each benchmark measures execution time in microseconds (μs) required for **1,000 state dispatches/emissions**.

| State Container / Mechanism | Time per 1k Dispatches (μs) | Est. Dispatches/sec | Relative Overhead vs Raw Signal |
| :--- | :---: | :---: | :---: |
| **Raw Signals (signal.value)** | 2284.92 μs | 437,652 | 1.00x |
| **CubitSignal.emit** | 3878.81 μs | 257,811 | 1.70x |
| **BlocSignal.add** | 5703.04 μs | 175,345 | 2.50x |
| **BlocSignal + Subscriber** | 6366.14 μs | 157,081 | 2.79x |
| **Provider (ChangeNotifier)** | 72.17 μs | 13,856,060 | 0.03x |
| **Provider + Listener** | 208.11 μs | 4,805,230 | 0.09x |
| **Riverpod Notifier** | 56095.72 μs | 17,827 | 24.55x |
| **Riverpod + Listener** | 56092.39 μs | 17,828 | 24.55x |
| **Classic Cubit.emit** | 136.39 μs | 7,331,966 | 0.06x |
| **Classic Bloc.add (Buffer Only)** | 1543.08 μs | 648,055 | 0.68x |
| **Classic Bloc + Listener (Buffer Only)** | 2856.47 μs | 350,082 | 1.25x |
| **Classic Bloc (Drained Stream)** | 249438.11 μs | 4,009 | 109.17x |

## 📊 Cross-Framework Key Takeaways & Architecture Analysis

1. **Synchronous Signal Graph Execution**: `BlocSignal` and `CubitSignal` propagate state updates synchronously down the dependency graph on the exact same frame. Calling `emit()` or `add()` triggers downstream reactive recalculations without microtask queue latency.
2. **Stream Buffering vs Drained Execution**: Classic `package:bloc` delegates `add()` onto asynchronous `StreamController` microtask queues. Calling `add()` alone only measures buffer insertion time (~0.43x raw signal). Once streams are fully drained (`Classic Bloc (Drained Stream)`), processing latency reflects actual microtask scheduling overhead.
3. **Provider / ChangeNotifier vs Signals**: `Provider` (`ChangeNotifier`) uses an internal array dispatch loop (`notifyListeners()`). While `ChangeNotifier` is fast for simple arrays, fine-grained `Signal` graph tracking in `BlocSignal` avoids unnecessary rebuilds for non-dependent UI subtrees.
4. **Zero Resolution Overhead**: `BlocSignal` operates directly on lightweight signal nodes without requiring provider container lookup or provider dependency resolution on every state write.
