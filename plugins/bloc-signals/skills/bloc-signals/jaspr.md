# Jaspr Web Integration (`bloc_signals_jaspr`)

`bloc_signals_jaspr` provides Jaspr web component state binding for `BlocSignal` and `CubitSignal` containers, maintaining **100% API and component parity with `bloc_signals_flutter`**.

---

## ⚡ Core Jaspr Components

| Component | Usage & Description |
| :--- | :--- |
| **`BlocSignalProvider<T>`** | Provides a `BlocSignal` or `CubitSignal` instance down the Jaspr component tree via `InheritedComponent`. Supports `lazy:` creation and `.value` injection. |
| **`MultiBlocSignalProvider`** | Combines multiple `BlocSignalProvider` instances into a single linear component hierarchy. |
| **`BlocSignalBuilder<T, S>`** | Rebuilds Jaspr components dynamically whenever container state updates. |
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

## 📝 Jaspr Web Example

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
