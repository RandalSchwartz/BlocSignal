# bloc_signals_replay

[![pub package](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-222222.svg)](https://pub.dev/packages/very_good_analysis)

Replay, undo, and redo state tracking utilities for `BlocSignal` and `CubitSignal` state containers.

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
