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
| **`otel_bloc_signals`** | OpenTelemetry tracing observers | 📦 [pub.dev](https://pub.dev/packages/otel_bloc_signals) |

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
  bloc_signals: ^0.2.5
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
          equals: (a, b) => a.id == b.id, // Custom identity equality
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

## 📜 Credits & Acknowledgements

Inspired by **[bloc](https://pub.dev/packages/bloc)** by **[Felix Angelov](https://github.com/felangel)** and **[signals](https://pub.dev/packages/signals)** by **[Rody Davis](https://github.com/roddydavis)**.
