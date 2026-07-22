---
name: bloc-signals
description: Core state management container integrating BLoC/Cubit patterns with reactive signals.
---

# BlocSignal Framework Guidelines & Reference

`BlocSignal` bridges the classic BLoC / Cubit patterns with Rody Davis's signals v7 primitives. It enables synchronous, de-duplicated state propagation, direct integration with signals utilities, and full observability.

> [!TIP]
> **Related Skills Recommendation**
> If you are working with `BlocSignal` and need advanced reactive primitives, Flutter UI bindings, hooks, linting rules, or migration guides, make sure you have the related signals skills installed:
> - `signals-dart` (advanced reactive state primitives and utilities of `signals_core`)
> - `signals-flutter` (highly optimized Flutter UI bindings for signals)
> - `signals-hooks` (reactive state hooks integrating signals with `flutter_hooks`)
> - `signals-lint` (static analysis rules and automated IDE quick-fixes for signals)
> - `signals-migration-6-to-7` (guidelines for migrating signals codebase from v6 to v7)
>
> If they are not already installed or configured, you can get/install them to enhance capabilities.

---


## 📚 Skill Structure & Details

| Resource | Description |
|---|---|
| [Core Guidelines & FAQ](core.md) | Synchronous lifecycle, automatic de-duplication, and FAQ (including sealed class exhaustiveness & effect/computed usage). |
| [Flutter Integration](flutter.md) | Reacting to state in Flutter widgets via `BlocSignalBuilder` and dependency injection using `BlocSignalProvider`. |
| [Interoperability Guide](interoperability.md) | Complete guide to the State Management Interoperability Trifecta (BLoC + Riverpod + Provider). |
| [OpenTelemetry Observability](otel.md) | Instrumenting event transitions, errors, and spans using `OtelBlocSignalObserver`. |
| [Testing Guidelines](testing.md) | Synchronous testing patterns, asynchronous event handler test styles, and lifecycle disposal expectations. |
| [Custom Lint Rules](lint.md) | IDE analysis diagnostics, core rules, and configuration guidelines for `bloc_signals_lint`. |
| [BLoC Migration Guide](migration.md) | Comprehensive walkthrough for migrating classic standard BLoCs/Cubits and UI providers to BlocSignal. |
| [Stream Migration Bridge](migration_bridge.md) | Bidirectional stream interop, `toStream()` extensions, and `toBlocSignal()` stream wrappers for progressive migration. |
| [Riverpod Migration Guide](riverpod_migration.md) | Complete guide for migrating Riverpod providers, ConsumerWidgets, and `.family` cache systems to BlocSignal / Signals. |




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
5. Replace UI `BlocBuilder` with `BlocSignalBuilder`, `BlocProvider` with `BlocSignalProvider`, `BlocListener` with `BlocSignalListener`, `BlocConsumer` with `BlocSignalConsumer`, and `BlocSelector` with `BlocSignalSelector`.

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
class CounterCubit extends CubitSignal<int> {
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
* **`BlocSignalBuilder`**: Rebuild UI on state changes:
  ```dart
  BlocSignalBuilder<CounterCubit, int>(
    builder: (context, count) => Text('$count'),
  )
  ```
* **`BlocSignalListener`**: Intercept state changes to run side-effects (navigation, dialogs):
  ```dart
  BlocSignalListener<AuthBloc, AuthState>(
    listener: (context, state) {
      if (state is Authenticated) Navigator.pushNamed(context, '/home');
    },
    child: const LoginForm(),
  )
  ```
* **`BlocSignalConsumer`**: Combine builder and listener patterns in a single widget:
  ```dart
  BlocSignalConsumer<CounterBloc, int>(
    listener: (context, count) {
      if (count == 10) showSnackbar(context, 'Limit!');
    },
    builder: (context, count) => Text('$count'),
  )
  ```
* **`BlocSignalSelector`**: Rebuild only when a selected portion of the state changes:
  ```dart
  BlocSignalSelector<UserBloc, UserState, String>(
    selector: (state) => state.username,
    builder: (context, username) => Text('Hello, $username'),
  )
  ```
