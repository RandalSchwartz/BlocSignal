# bloc_signals_jaspr

[![pub package](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Jaspr web component integration and state binding for [`bloc_signals`](https://pub.dev/packages/bloc_signals) state containers.

`bloc_signals_jaspr` provides complete API and component parity with `bloc_signals_flutter`, allowing you to use `BlocSignal` and `CubitSignal` containers seamlessly within Jaspr web applications.

---

## 🌐 Ecosystem Packages

The `BlocSignal` monorepo consists of 10 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |

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
  bloc_signals_jaspr: ^1.0.0
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
