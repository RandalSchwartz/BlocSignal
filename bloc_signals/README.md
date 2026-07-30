# ⚡ bloc_signals

> *"With the rigor of Bloc and the flex and speed of Signal"*

A synchronous state management library bridging the Business Logic Component (BLoC) pattern with a reactive signals foundation (using Rody Davis's `signals` package version 7).

This package provides core pure-Dart reactive state containers (`BlocSignalBase`, `CubitSignal`, `BlocSignal`), event concurrency transformers (`Mutex`, `droppable`, `sequential`, `restartable`), VM Service telemetry (`DevToolsBlocSignalObserver`, `DevToolsService`), and stream interop extensions.

---

## 🌐 Ecosystem Packages

| Package | Purpose | Pub.dev Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state containers, event registry, & VM Service telemetry | 📦 [pub.dev](https://pub.dev/packages/bloc_signals) |
| **`bloc_signals_flutter`** | Flutter UI widgets (`BlocSignalProvider`, `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_flutter) |
| **`bloc_signals_riverpod`** | Bidirectional Riverpod interop adapters (`toBlocSignal(ref)`, `toProvider()`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_riverpod) |
| **`bloc_signals_hydrate`** | Persistent state storage (`HydratedCubitSignal`, `HydratedBlocSignal`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_hydrate) |
| **`bloc_signals_devtools`** | Dedicated Flutter DevTools extension inspector UI | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_devtools) |
| **`bloc_signals_test`** | Declarative unit testing helpers (`blocSignalTest`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_test) |
| **`bloc_signals_lint`** | Static analysis lints & IDE quick-fixes | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_lint) |
| **`bloc_signals_otel`** | OpenTelemetry tracing observers | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_otel) |

---

## ⚡ Key Features

- 🚀 **Synchronous Propagation**: `emit()` updates state immediately in the exact same frame without microtask delay.
- 🎯 **Automatic De-duplication**: Identical states (`==` or custom equality) are automatically de-duplicated to prevent unnecessary downstream recalculations.
- 🔒 **Streamless Concurrency**: Support for `Mutex`, `droppable()`, `sequential()`, and `restartable()` event transformers without stream overhead.
- 🛠️ **DevTools & Telemetry**: Built-in VM Service RPC extensions (`DevToolsService`) and standard `dart:developer` event posting (`DevToolsBlocSignalObserver`).

---

## 🚀 Getting Started

Add `bloc_signals` to your `pubspec.yaml`:

```yaml
dependencies:
  bloc_signals: ^0.2.7
```

---

## 💡 Quick Examples

### 1. CubitSignal (Simple State Management)

```dart
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

void main() {
  final counter = CounterCubit();
  print(counter.stateValue); // 0
  counter.increment();
  print(counter.stateValue); // 1
  counter.close();
}
```

### 2. BlocSignal (Event-Driven State Management)

```dart
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
final class IncrementEvent extends CounterEvent {}
final class DecrementEvent extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<DecrementEvent>((event, emit) => emit(stateValue - 1));
  }
}

void main() {
  final bloc = CounterBloc();
  bloc.add(IncrementEvent()); // Synchronously transitions state to 1
  print(bloc.stateValue); // 1
  bloc.close();
}
```

### 3. Event Concurrency Transformers (`droppable`, `sequential`, `restartable`)

```dart
class AsyncDataBloc extends BlocSignal<DataEvent, DataState> {
  AsyncDataBloc(Repository repo) : super(initialState: DataInitial()) {
    // Drop incoming FetchData events while current handler is active
    on<FetchData>(
      (event, emit) async {
        final data = await repo.load();
        emit(DataLoaded(data));
      },
      transformer: droppable(),
    );
  }
}
```

### 4. Custom Equality Comparators

```dart
class UserBloc extends CubitSignal<UserModel> {
  UserBloc(UserModel initial)
      : super(
          initialState: initial,
          equals: (a, b) => a.id == b.id, // Custom property equality
        );
}
```

### 5. Stream Interop Extensions

```dart
// Convert any BlocSignal into a Dart Stream
final Stream<int> stream = counterBloc.toStream();

// Convert any Dart Stream into a StreamBlocSignal
final streamBloc = stream.toBlocSignal(initialState: 0);
```

---

## 🏷️ Debug Names, Signal Options & Custom Equality

All `BlocSignalBase` containers (`CubitSignal`, `BlocSignal`), side-effect handlers (`createEffect`), and Flutter selectors (`BlocSignalSelector`) accept explicit options configuration (`SignalOptions`, `EffectOptions`, `ComputedOptions`) and generate descriptive automatic debug names for DevTools inspection.

### 1. Automatic & Custom Debug Names
By default, state signals and internal effects are assigned rich diagnostic names in VM Service / DevTools telemetry:
- State Signal: `'$runtimeType.state'` (e.g. `'CounterCubit.state'`)
- Lifecycle Effect: `'$runtimeType.lifecycleEffect'`
- Custom Effects: `'$runtimeType.effect#1'`, `'$runtimeType.effect#2'`

You can customize debug names using the `options:` parameter:
```dart
final cubit = CounterCubit(
  options: SignalOptions<int>(name: 'CustomCounterCubit.state'),
);
```

### 2. Custom Equality & Identity Comparison (`identical`)
By default, state updates use standard value equality (`previous == current`). You can customize state de-duplication strategy using `equals:` or `options:`.

#### 💡 FAQ: How do I force Reference Identity Equality (`identical`)?
To ensure every `emit()` call triggers a state update regardless of `==` value equality, pass Dart's built-in `identical` top-level function tear-off:

```dart
// Option A: Passing `identical` tear-off to the constructor
class ForceRebuildCubit extends CubitSignal<StateModel> {
  ForceRebuildCubit(StateModel initial)
      : super(initialState: initial, equals: identical);
}

// Option B: Using SignalOptions.identity()
class IdentityBloc extends CubitSignal<StateModel> {
  IdentityBloc(StateModel initial)
      : super(
          initialState: initial,
          options: SignalOptions(equality: SignalEquality.identity()),
        );
}
```

#### ⚖️ Equality Evaluation Precedence Order
1. `options.equality` *(highest priority if specified in `SignalOptions`)*
2. `equals` constructor parameter or `@override bool equals(...)` method
3. Default value equality (`previous == current`)

---

## 🔍 DevTools & Telemetry Setup

Enable global DevTools telemetry in `main.dart`:

```dart
void main() {
  // Enables VM Service RPC extensions & developer.postEvent telemetry
  BlocSignalObserver.observer = DevToolsBlocSignalObserver();

  runApp(const MyApp());
}
```

---

## 🤖 AI Coding Assistant Skill & Guides

This package is supported by official pre-packaged AI Coding Skills and architectural documentation guides representing best practices, lifecycle contracts, and usage patterns for `BlocSignal`:

- 🔄 **[Migration Guide](https://github.com/RandalSchwartz/BlocSignal/blob/main/plugins/bloc-signals/skills/bloc-signals/migration.md)**: Transitioning from classic `package:bloc` / `package:flutter_bloc` to `BlocSignal`.
- 🌁 **[Universal Interoperability Guide](https://github.com/RandalSchwartz/BlocSignal/blob/main/plugins/bloc-signals/skills/bloc-signals/interoperability.md)**: Bridging state containers across BLoC, Riverpod, Provider, and Listenable primitives.
- 📦 **[AI Skill Bundle](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals)**: Load the pre-packaged `bloc-signals` skill bundle for AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex) to guide code generation and analysis.

---

## 📜 Credits & Acknowledgements

Inspired by **[bloc](https://pub.dev/packages/bloc)** by **[Felix Angelov](https://github.com/felangel)** and **[signals](https://pub.dev/packages/signals)** by **[Rody Davis](https://github.com/roddydavis)**.
