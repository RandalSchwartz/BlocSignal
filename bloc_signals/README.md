<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        A synchronous state management library bridging the Business Logic Component (BLoC) 
        pattern with a reactive signals foundation (using Rody Davis's <code>signals</code> package v7).
      </p>
    </td>
  </tr>
</table>

This package provides core pure-Dart reactive state containers (`BlocSignalBase`, `CubitSignal`, `BlocSignal`), event concurrency transformers (`Mutex`, `droppable`, `sequential`, `restartable`), VM Service telemetry (`DevToolsBlocSignalObserver`, `DevToolsService`), and stream interop extensions.

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
