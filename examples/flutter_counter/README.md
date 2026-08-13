# Flutter Counter Example (`CubitSignal` vs `BlocSignal`)

A side-by-side comparison example demonstrating the two core reactive state containers in `BlocSignal`: `CubitSignal` and `BlocSignal`.

## ✨ Features

- **CubitSignal (Imperative)**: Direct method invocation (`increment()`, `decrement()`) with minimal boilerplate.
- **BlocSignal (Event-Driven)**: Reified event dispatching (`CounterIncremented`, `CounterDecremented`) via `add()` with complete transition tracing.
- **Synchronous Updates**: State emissions update downstream widgets immediately without microtask queue latency.
- **Automatic De-duplication**: Transitions that result in `stateValue == newState` are dropped automatically.

## 🔗 Upstream Reference

- Inspired by the standard [flutter_counter](https://bloclibrary.dev/tutorials/flutter-counter/) example from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_counter
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_counter
flutter test
```
