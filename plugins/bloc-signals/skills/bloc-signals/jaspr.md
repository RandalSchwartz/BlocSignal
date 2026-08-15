# Jaspr Web Integration (`bloc_signals_jaspr`)

`bloc_signals_jaspr` provides Jaspr web component state binding for `BlocSignal` and `CubitSignal` containers, maintaining **100% API and component parity with `bloc_signals_flutter`**.

---

## ⚡ Core Jaspr Components

| Component | Usage & Description |
| :--- | :--- |
| **`BlocSignalProvider<T>`** | Provides a `BlocSignal` or `CubitSignal` instance down the Jaspr component tree via `InheritedComponent`. Supports `lazy:` creation and `.value` injection. |
| **`MultiBlocSignalProvider`** | Combines multiple `BlocSignalProvider` instances into a single linear component hierarchy. |
| **`BlocSignalBuilder<T, S>`** | Rebuilds Jaspr components dynamically whenever container state updates with automatic subscription teardown. |
| **`BlocSignalListener<T, S>`** | Fires side-effect callbacks (such as notifications or JS interop calls) on state updates with optional `listenWhen` predicate filtering. |
| **`BlocSignalConsumer<T, S>`** | Combines `BlocSignalBuilder` and `BlocSignalListener`. |
| **`BlocSignalSelector<T, S, V>`** | Subscribes to fine-grained computed state slices and rebuilds only when selection changes. |
| **`MultiBlocSignalListener`** | Combines multiple `BlocSignalListener` instances cleanly. |

---

## 💡 BuildContext Extensions

- **`context.read<T>()`**: Reads container instance without registering a component rebuild dependency.
- **`context.watch<T>()`**: Listens to provider updates and rebuilds component on container reference swap.
- **`context.select<T, R>(selector)`**: Subscribes to a computed state derivation and marks component dirty only when selection changes.

---

## 🛡️ Best Practices & Anti-Patterns

### 1. Prefer Declarative Builders Over Raw `.subscribe()` in `StatefulComponent`
* **Anti-Pattern (Double `setState` & Unhandled Subscriptions)**:
  ```dart
  // ❌ AVOID: Double-triggering setState and unhandled subscription closures
  @override
  void initState() {
    super.initState();
    _bloc.state.subscribe((val) {
      if (mounted) setState(() {}); // Fires redundant setState alongside onClick
    });
  }
  ```
  Calling `_bloc.state.subscribe(...)` manually inside `initState` causes:
  1. **Double Re-renders**: UI handlers (like `onClick`) calling `setState()` alongside `_bloc.add()` trigger two back-to-back framework rebuild passes on every event.
  2. **Batch UI Thrashing**: High-frequency loops or benchmarks (e.g. 1,000 events) force 1,000 individual `setState()` calls during the loop.
  3. **Resource Retain**: The subscription handle returned by `.subscribe()` must be captured and cancelled in `dispose()`.

* **Idiomatic Approach**:
  Use `BlocSignalBuilder` or `BlocSignalBuilder.value` to let the framework manage subscription lifecycle and dirty flags automatically:
  ```dart
  // ✅ RECOMMENDED: Declarative binding with automatic lifecycle teardown
  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<CounterCubit, int>(
      builder: (context, count) => h1([Component.text('Count: $count')]),
    );
  }
  ```

### 2. Fine-Grained Reactive Updates with `BlocSignalSelector`
Use `BlocSignalSelector` when child components only need to re-render when a specific slice of the container state changes:
```dart
// Rebuilds ONLY when the derived doubled count changes
BlocSignalSelector<CounterBloc, int, int>(
  selector: (state) => state * 2,
  builder: (context, doubled) => span([Component.text('Doubled: $doubled')]),
)
```

---

## 📝 Jaspr Web Example

### Classic Dart 3.5 Syntax
```dart
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

class CounterApp extends StatelessComponent {
  const CounterApp({super.key});

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider(
      create: (context) => CounterCubit(),
      child: div([
        BlocSignalBuilder<CounterCubit, int>(
          builder: (context, count) {
            return h1([Component.text('Count: $count')]);
          },
        ),
        button(
          onClick: () => context.read<CounterCubit>().increment(),
          [Component.text('Increment')],
        ),
      ]),
    );
  }
}
```

### Modern Dart 3.13 Primary Constructor Syntax
```dart
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class CounterCubit() extends CubitSignal<int> {
  this : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

class const CounterApp({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>(
      create: (_) => CounterCubit(),
      child: div([
        BlocSignalSelector<CounterCubit, int, int>(
          selector: (state) => state,
          builder: (context, count) => h1([Component.text('Count: $count')]),
        ),
        button(
          onClick: () => context.read<CounterCubit>().increment(),
          [Component.text('Increment')],
        ),
      ]),
    );
  }
}
```

