# Async State Example (`CubitSignal` & `AsyncState`)

An asynchronous state management example demonstrating how `CubitSignal` pairs with `AsyncState` (`AsyncData`, `AsyncLoading`, `AsyncError`).

## ✨ Features

- **Standardized Async Transitions**: Eliminates ad-hoc boolean status flags and nullable payload models by wrapping state in `AsyncState<T>`.
- **Pattern Matching UI**: Uses exhaustive Dart 3 `switch (state)` expressions for guaranteed compile-time handling of loading, success, and error states.
- **Synchronous Graph Updates**: Fast, glitch-free UI transitions without microtask queue latency.
- **Simulated Error Handling & Retries**: Interactive buttons to trigger error conditions and test retry resilience.

## 🚀 Running the Example

```bash
cd examples/flutter_async
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_async
flutter test
```
