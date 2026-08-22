---
series: "BlocSignal Architecture & Practice"
title: "Introducing BlocSignal: Unidirectional Data Flow Meets Reactive Signals"
description: "Bridge the architectural boundaries of BLoC/Cubit with the synchronous performance and simplicity of reactive Signals in Dart and Flutter."
tags: flutter, dart, statemanagement, blocsignal
published: true
---

State management in Flutter has always been a tale of two philosophies:
1. **The Unidirectional, Event-Driven Architecture (BLoC/Cubit):** Exceptional for structuring business logic in large-scale applications. It provides clear separations, standard developer workflows, and centralized transition observers. But it runs on Dart `Stream`s, introducing asynchronous microtask scheduling and event-propagation lag.
2. **Fine-Grained Reactive Primitives (Signals):** Blazing fast, synchronous, and boilerplate-free. However, without standard guardrails, pure signal codebases can sometimes feel like the "Wild West" when multiple developers try to coordinate complex side effects.

What if you could have the architectural safety and predictability of BLoC combined with the performance and reactive simplicity of Signals?

Enter **`BlocSignal`**.

`BlocSignal` bridges these two paradigms, bringing synchronous, glitch-free propagation, automatic state de-duplication, and advanced signals reactivity to the classic BLoC pattern.

---

## ⚡ Why BlocSignal?

In classic BLoC, every emitted state is dispatched asynchronously on a stream. If you emit identical states consecutively, downstream widgets rebuild anyway unless you configure distinct filters.

`BlocSignal` rewrites the engine under the hood:
* **Synchronous Propagation:** State updates via `emit(newState)` propagate instantly to downstream calculations and widget rebuilds in the exact same frame. No more waiting on microtasks.
* **Automatic De-duplication:** States are automatically compared using `==` equality. If a state doesn't change, downstream effects and builders are skipped entirely.
* **Declarative Reactivity:** The bloc exposes its state as a reactive `ReadonlySignal<State>`. This allows you to compose derived state properties using `computed(...)` and register side effects via `effect(...)`.

---

## 🛠️ The Event Handler Design: Two Flavors of Safety

When managing events in standard BLoC, you typically register handlers in the constructor scope using `.on<Event>`. In `BlocSignal`, we support both this dynamic registration pattern and compile-time safe pattern matching.

### 🧬 Flavor 1: Dynamic Registration with `.on<Event>`

This is the familiar, standard BLoC approach. It is dynamic and easy to write:

```dart
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    // Dynamic runtime registration
    on<Increment>((event, emit) => emit(stateValue + 1));
    on<Decrement>((event, emit) => emit(stateValue - 1));
  }
}
```

*When to use:* Perfect for simple event topologies or when mapping a small set of actions.

### 🛡️ Flavor 2: Compile-Time Safe Exhaustiveness with Switch Expressions

Because `.on<T>` registers handlers dynamically at runtime, the Dart compiler cannot verify if you've handled every subclass of a `sealed` class. 

To achieve **100% compile-time safety**, you can override `onEvent(event)` and use a Dart **switch expression**. If you add a new event subclass and forget to handle it, your project will fail to compile, preventing runtime bugs:

```dart
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}
class Reset extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  FutureOr<void> onEvent(CounterEvent event) {
    // The compiler strictly enforces that all CounterEvent subclasses are handled
    final nextState = switch (event) {
      Increment() => stateValue + 1,
      Decrement() => stateValue - 1,
      Reset()     => 0,
    };
    emit(nextState);
  }
}
```

*When to use:* Production enterprise features with complex, evolving sealed event hierarchies.

---

## 🎨 Consuming State in Flutter

Integrating `BlocSignal` into your Flutter widgets is a breeze. It uses familiar provider/builder APIs, but optimizes them using signal-based rebuilding.

### 1. Providing the State
Inject your state container into the widget tree using `BlocSignalProvider`:

```dart
BlocSignalProvider<CounterBloc>(
  create: (context) => CounterBloc(),
  child: const CounterScreen(),
)
```
*(Note that `BlocSignal` for Flutter doesn't use the `Provider` package—we implement our own lightweight `InheritedWidget` subclass, eliminating one more external dependency.)*

### 2. Building the UI
Rebuild sections of the UI using `BlocSignalBuilder`. Because it reads the underlying signal value, it subscribes and unsubscribes from state changes automatically:

```dart
BlocSignalBuilder<CounterBloc, int>(
  builder: (context, count) {
    return Text(
      '$count',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  },
)
```

---

## 🚀 Advanced Composition: Computed Signals & Effects

Since the state is powered by standard Dart `signals`, you can compose derived state effortlessly:

### Inside the Constructor (Scoped)
You can declare reactive signals properties directly inside the class constructor. They will automatically be disposed of when the bloc is closed:

```dart
class TaskBloc extends BlocSignal<TaskEvent, List<Task>> {
  late final ReadonlySignal<int> completedCount;

  TaskBloc() : super(initialState: []) {
    // Automatically updates whenever the state changes
    completedCount = computed(() => stateValue.where((t) => t.isCompleted).length);
    
    // Auto-disposed side effects
    effect(() {
      print('Outstanding tasks: ${stateValue.length - completedCount()}');
    });
  }
}
```

### Outside the Constructor (Consumer)
Consumers can subscribe to a bloc's reactive `state` signal directly to create external computed chains:

```dart
final taskBloc = TaskBloc();

// External computed signal
final hasOutstandingTasks = computed(() => taskBloc.state().any((t) => !t.isCompleted));
```

---

## 📈 Enterprise Observability

In production environments, tracking state transitions is critical. `BlocSignal` zones track transitions triggered by specific events. 

By registering the `OtelBlocSignalObserver` (from `otel_bloc_signals`), transitions, actions, and errors map directly to OpenTelemetry traces, ensuring you have absolute visibility into user flows:

```dart
BlocSignalObserver.instance = OtelBlocSignalObserver(
  tracerProvider: myTracerProvider,
);
```

---

## 🏁 Summary & Resources

`BlocSignal` takes the best parts of two worlds. It gives you the structured boundaries and event hierarchies of BLoC/Cubit, backed by the raw performance, synchronous execution, and declarative power of Signals.

Ready to check it out? Explore the packages on Pub:

* 📦 **[bloc_signals](https://pub.dev/packages/bloc_signals)** – Core state management container.
* 📦 **[bloc_signals_flutter](https://pub.dev/packages/bloc_signals_flutter)** – High-performance widgets and custom providers.
* 📦 **[otel_bloc_signals](https://pub.dev/packages/otel_bloc_signals)** – OpenTelemetry tracing and observability observer.
* 💻 **[GitHub Repository](https://github.com/RandalSchwartz/BlocSignal)**
