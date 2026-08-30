# bloc_signals_replay

[![pub package](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-222222.svg)](https://pub.dev/packages/very_good_analysis)

Replay, undo, and redo state tracking utilities for `BlocSignal` and `CubitSignal` state containers.

---

## 🌐 Ecosystem Packages

The `BlocSignal` monorepo consists of 11 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_bloc`** | [![pub](https://img.shields.io/pub/v/bloc_signals_bloc.svg)](https://pub.dev/packages/bloc_signals_bloc) | Classic BLoC 8/9 interop adapters & bidirectional event bridges |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |

---

## ⚡ Overview

`bloc_signals_replay` brings automatic undo and redo state management capabilities to `BlocSignal` and `CubitSignal`, mirroring Felix Angelov's `replay_bloc` package architecture.

- **`ReplayCubit` / `ReplayCubitMixin`**: Undo and redo stack support for method-driven `CubitSignal` containers.
- **`ReplayBloc` / `ReplayBlocMixin`**: Undo and redo stack support for event-driven `BlocSignal` containers, with synthetic `_Undo` and `_Redo` transition tracing.
- **`_ChangeStack`**: Configurable history limits and `shouldReplay` state filtering.

---

## 🚀 Quick Start

### `ReplayCubit`

Extend `ReplayCubit` to automatically track state changes:

```dart
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class CounterCubit extends ReplayCubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(stateValue + 1);
}

void main() {
  final cubit = CounterCubit();

  cubit.increment(); // state is 1
  print(cubit.canUndo); // true

  cubit.undo();      // state reverts to 0
  print(cubit.canRedo); // true

  cubit.redo();      // state becomes 1
}
```

### `ReplayBloc`

Extend `ReplayBloc` for event-driven state containers:

```dart
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

sealed class CounterEvent extends ReplayEvent {
  const CounterEvent();
}

final class Increment extends CounterEvent {
  const Increment();
}

class CounterBloc extends ReplayBloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
  }
}

void main() {
  final bloc = CounterBloc();

  bloc.add(const Increment()); // state is 1
  bloc.undo();                 // state is 0
  bloc.redo();                 // state is 1
}
```

### Stack Bounds & State Filtering

Pass a `limit` parameter or override `shouldReplay` to control undo/redo behavior:

```dart
class BoundedCubit extends ReplayCubit<int> {
  // Cap undo stack depth to 5 states
  BoundedCubit() : super(0, limit: 5);

  // Skip even states during replay
  @override
  bool shouldReplay(int state) => !state.isEven;
}
```
