# Replay & Undo/Redo State Tracking (`bloc_signals_replay`)

The `bloc_signals_replay` package provides automatic undo and redo state tracking for `BlocSignal` and `CubitSignal` containers, mirroring Felix Angelov's `replay_bloc` package design.

---

## ⚡ Key Components

- **`ReplayCubit<State>` & `ReplayCubitMixin<State>`**: Extends or mixes into `CubitSignal<State>` to provide `undo()`, `redo()`, `canUndo`, `canRedo`, `clearHistory()`, `limit`, and `shouldReplay(state)`.
- **`ReplayBloc<Event, State>` & `ReplayBlocMixin<Event, State>`**: Extends or mixes into `BlocSignal<Event, State>` to provide undo/redo history tracking. Emits synthetic `_Undo` and `_Redo` events into `onEvent` and `onTransition` so observers track replay actions.
- **`ReplayEvent`**: Base event class for `ReplayBloc` events.

---

## 🚀 Basic Usage

### `ReplayCubit` Example

```dart
import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class CounterCubit extends ReplayCubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(stateValue + 1);
}

void main() {
  final cubit = CounterCubit();

  cubit.increment();    // stateValue is 1
  assert(cubit.canUndo);

  cubit.undo();         // stateValue is 0
  assert(cubit.canRedo);

  cubit.redo();         // stateValue is 1
}
```

### `ReplayBloc` Example

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

---

## ⚙️ Advanced Configuration

### History Limit (`limit`)

Limit the maximum number of historical states stored in memory:

```dart
class BoundedCubit extends ReplayCubit<int> {
  // Store a maximum of 10 history entries
  BoundedCubit() : super(0, limit: 10);
}
```

### Selective Replaying (`shouldReplay`)

Override `shouldReplay` to filter out intermediate or ephemeral states during undo/redo traversal:

```dart
class SelectiveCubit extends ReplayCubit<MyState> {
  SelectiveCubit() : super(MyInitialState());

  @override
  bool shouldReplay(MyState state) {
    // Only replay persistent states, skipping transient loading states
    return state is! LoadingState;
  }
}
```
