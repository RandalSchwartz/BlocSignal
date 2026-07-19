---
name: bloc-signals
description: Core state management container integrating BLoC/Cubit patterns with reactive signals.
---

# BlocSignal Framework Guidelines & Reference

`BlocSignal` bridges the classic BLoC / Cubit patterns with Rody Davis's signals v7 primitives. It enables synchronous, de-duplicated state propagation, direct integration with signals utilities, and full observability.

---

## 📚 Skill Structure & Details

| Resource | Description |
|---|---|
| [Core Guidelines & FAQ](core.md) | Synchronous lifecycle, automatic de-duplication, and FAQ (including sealed class exhaustiveness & effect/computed usage). |
| [Flutter Integration](flutter.md) | Reacting to state in Flutter widgets via `BlocSignalBuilder` and dependency injection using `BlocSignalProvider`. |
| [OpenTelemetry Observability](otel.md) | Instrumenting event transitions, errors, and spans using `OtelBlocSignalObserver`. |
| [Testing Guidelines](testing.md) | Synchronous testing patterns, asynchronous event handler test styles, and lifecycle disposal expectations. |
| [BLoC Migration Guide](migration.md) | Comprehensive walkthrough for migrating classic standard BLoCs/Cubits and UI providers to BlocSignal. |



---

## 🔄 BLoC to BlocSignal Migration Guide

For the full detailed step-by-step transition walkthrough (including UI provider injection and MultiBlocProvider migration), refer to the **[Migration Guide](migration.md)**.

Migrating standard BLoCs/Cubits to `BlocSignal` increases performance, simplifies widget bindings, and guarantees synchronous, glitch-free propagation.

### 1. The Migration Pattern
* Standard BLoC runs asynchronously on microtask-queue Streams. `BlocSignal` runs synchronously.
* Standard BLoC triggers transition callbacks for every emitted state (even if equal). `BlocSignal` automatically de-duplicates states that evaluate equal (`==`).

### 2. Side-by-Side Comparison

#### Legacy BLoC (Streams)
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
  }
}
```

#### Modern BlocSignal
```dart
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
  }
}
```

### 3. Key Migration Steps
1. Replace `package:flutter_bloc/flutter_bloc.dart` with `package:bloc_signals/bloc_signals.dart` and `package:bloc_signals_flutter/bloc_signals_flutter.dart`.
2. Inherit from `BlocSignal<Event, State>` instead of `Bloc`.
3. Provide `initialState` via the `super` constructor parameter: `super(initialState: ...)`.
4. Replace `state` with `stateValue` inside handlers, or use `state` (which returns the underlying `ReadonlySignal<State>`).
5. Replace UI `BlocBuilder` with `BlocSignalBuilder`, and `BlocProvider` with `BlocSignalProvider`.

---

## ⚡ Core API & Frequent Patterns Cheat Sheet

Here is a quick-reference index of the primary APIs and patterns:

### 1. BLoC (Event-driven) Pattern
Use when you want unidirectional, decoupled event-based state changes:
```dart
class MyBloc extends BlocSignal<MyEvent, MyState> {
  MyBloc() : super(initialState: const MyState.initial()) {
    on<LoadEvent>((event, emit) async {
      emit(const MyState.loading());
      try {
        final data = await repository.fetch();
        emit(MyState.success(data));
      } catch (e) {
        emit(MyState.failure(e));
      }
    });
  }
}

// Consuming:
myBloc.add(LoadEvent());
```

### 2. Cubit (Method-driven) Pattern
Use when you want direct method calls on the state container instead of dispatching event objects:
```dart
class CounterCubit extends BlocSignal<void, int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

// Consuming:
myCubit.increment();
```

### 3. Accessing & Linking State
* **`stateValue`**: Get current raw state synchronously (`final s = bloc.stateValue`).
* **`state`**: Get the reactive `ReadonlySignal<State>` to plug into external signal logic (`final sig = bloc.state`).
* **`computed`**: Derive reactive state properties inside the constructor:
  ```dart
  late final ReadOnlySignal<bool> isEmpty = computed(() => stateValue == 0);
  ```

### 4. Scoping & Rebuilding in Flutter
* **`BlocSignalProvider`**: Inject the bloc instance:
  ```dart
  BlocSignalProvider<CounterCubit>(
    create: (context) => CounterCubit(),
    child: const MyWidget(),
  )
  ```
* **`BlocSignalBuilder`**: Rebuild UI on state changes (lookup from provider context is automatic if `bloc` is omitted):
  ```dart
  BlocSignalBuilder<CounterCubit, int>(
    builder: (context, count) => Text('$count'),
  )
  ```

