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
  CounterCubit() : super(initialState: 0);

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
  CounterBloc() : super(initialState: 0) {
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
  BoundedCubit() : super(initialState: 0, limit: 10);
}
```

- **Dynamic Limit Adjustment**: The history bound can be inspected via `limit` getter or modified at runtime via `cubit.limit = newLimit` (or `bloc.limit = newLimit`). Lowering `limit` immediately trims existing history to the new bound, evicting the oldest entries first.
- **Clearing via Zero Limit**: Setting `limit <= 0` immediately clears both history and redo queues, disabling further tracking until a positive limit (or `null`) is set.
- **Unbounded History**: Setting `limit = null` removes bounds and allows unlimited history recording.
- **Redo History Enforcement**: When replaying previously undone states via `redo()`, the history queue is trimmed to `limit` as changes are restored, preventing history size from exceeding the configured bound if `limit` was lowered while entries resided in the redo stack.

### Selective Replaying (`shouldReplay`)

Override `shouldReplay` to filter out intermediate or ephemeral states during undo/redo traversal:

```dart
class SelectiveCubit extends ReplayCubit<MyState> {
  SelectiveCubit() : super(initialState: MyInitialState());

  @override
  bool shouldReplay(MyState state) {
    // Only replay persistent states, skipping transient loading states
    return state is! LoadingState;
  }
}
```

- **Atomic Single-Pass Traversal**: `undo()` and `redo()` evaluate `shouldReplay` in a single linear pass ($O(N)$) from the active end of the stack rather than recursive $O(N^2)$ re-scans.
- **Atomic Rollback on Traversal Exhaustion**: If no candidate state satisfies `shouldReplay`, skipped changes are not drained into the opposite stack; the traversal cleanly preserves the existing queues without modifying the container's state.
- **Symmetric Traversal Across Intermediate Skips**: Undoing across multiple filtered states and subsequently redoing restores corresponding states symmetrically.

---

## 🛡️ Replay Execution Protection & Lifecycle Gating

### Duplicate Emission Protection
Calling `undo()` or `redo()` internally triggers an `emit()` to restore the selected state. To prevent these internal restorations from pushing duplicate entries into the undo stack or erasing the redo stack, `ReplayCubitMixin` and `ReplayBlocMixin` use internal reentrancy flags (`_isReplaying`).

### Lifecycle Gating
- **Post-Close Safety**: Once `close()` has been called, subsequent emissions (for example from pending asynchronous tasks) are strictly prevented from mutating or appending to the undo/redo history stack.
- **De-duplication**: When an `emit()` produces a value identical to the current state (`equals(stateValue, newState)`), it is skipped and does not pollute the history stack.
- **Synthetic Event Routing**: In `ReplayBloc`, internal `_Undo` and `_Redo` events are routed with replay tags so external `onTransition` observers do not receive duplicate notifications.
- **Observer & Hook Exception Isolation (`SCAR-CORE-12`)**: During `undo()` and `redo()`, any `Exception` thrown by `BlocSignalObserver.onEvent`, `onTransition`, `onChange`, or a custom `onEvent` override (whether synchronous or asynchronous) is caught and routed to `onError()` without aborting state restoration.

