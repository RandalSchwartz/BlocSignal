# bloc_signals_jaspr

[![pub package](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Jaspr web component integration and state binding for [`bloc_signals`](https://pub.dev/packages/bloc_signals) state containers.

`bloc_signals_jaspr` provides complete API and component parity with `bloc_signals_flutter`, allowing you to use `BlocSignal` and `CubitSignal` containers seamlessly within Jaspr web applications.

---

## ⚡ Features

- **`BlocSignalProvider<T>`**: Injects a `BlocSignal` or `CubitSignal` into the Jaspr component tree via `InheritedComponent`, supporting lazy initialization (`lazy: true`), existing values (`.value`), and automatic container disposal.
- **`MultiBlocSignalProvider`**: Combines multiple providers into a single linear component tree.
- **`BuildContext` Extensions**: Read (`context.read<T>()`), watch (`context.watch<T>()`), and selectively subscribe (`context.select<T, R>()`) directly from `BuildContext`.
- **`BlocSignalBuilder<T, S>`**: Rebuilds Jaspr components dynamically when state changes.
- **`BlocSignalListener<T, S>`**: Executes side-effect callbacks on state changes with optional `listenWhen` filtering.
- **`BlocSignalConsumer<T, S>`**: Combines `BlocSignalBuilder` and `BlocSignalListener`.
- **`BlocSignalSelector<T, S, V>`**: Fine-grained component rebuild filtering using computed state slices.
- **`MultiBlocSignalListener`**: Merges multiple listeners cleanly.

---

## 🚀 Quickstart

Add `bloc_signals_jaspr` to your `pubspec.yaml`:

```yaml
dependencies:
  bloc_signals_jaspr: ^0.1.0
```

### Providing & Consuming State in Jaspr

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
      child: const CounterView(),
    );
  }
}

class CounterView extends StatelessComponent {
  const CounterView({super.key});

  @override
  Component build(BuildContext context) {
    return div([
      BlocSignalBuilder<CounterCubit, int>(
        builder: (context, state) {
          return h1([Component.text('Count: $state')]);
        },
      ),
      button(
        onClick: () => context.read<CounterCubit>().increment(),
        [Component.text('Increment')],
      ),
    ]);
  }
}
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
