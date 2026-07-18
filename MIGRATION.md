# Migration Guide: From classic `bloc` to `BlocSignal`

This guide explains how to migrate your Flutter and Dart applications from classic BLoC (`package:bloc` and `package:flutter_bloc`) to `BlocSignal` (`package:bloc_signals` and `package:bloc_signals_flutter`).

## Core Paradigm Shift: Streams vs. Signals

`BlocSignal` offers a synchronous, glitch-free alternative to classic BLoC while maintaining its core architectural predictability (events in, states out).

### Synchronous Propagation (No Microtask Delay)
Classic BLoC is built on Dart `Stream`s, which are asynchronous and rely on the Dart microtask queue. When you emit a state in classic BLoC, the UI rebuild is scheduled for the next frame. This can lead to transient "UI glitches" or race conditions when multiple states depend on one another.
In contrast, `BlocSignal` relies on reactive signals. State propagation is immediate and **synchronous**: calling `emit()` updates the state value instantly in the current execution block, recalculating the reactive dependency graph and triggering UI rebuilds in the exact same frame.

### Feature Parity & Stream Limitations
While `BlocSignal` mimics BLoC's lifecycle, dependency injection, and state encapsulation, it is not a 1:1 drop-in replacement. Because `BlocSignal` does not use streams under the hood, standard stream manipulation features (such as `debounce`, `throttle`, `distinct`, or RxDart operators like `switchMap` and `flatMap`) are not natively available on the state container. If your business logic relies heavily on stream-transforming event transformers, you will need to map these behaviors using custom debouncers or reactive signal effects.

### Automatic State De-duplication
In classic BLoC, emitting the exact same state value multiple times will propagate downstream through the stream unless you filter it manually using `.distinct()`.
With `BlocSignal`, reactive signals automatically **de-duplicate equal values** (using `==` equality) at the primitive layer. If you call `emit()` with a state that is equal to the current state, downstream effects and UI builders will not be notified or rebuilt. This reduces redundant widget builds by default without requiring manual configuration.

---

## Key Conceptual Differences

| Feature | Classic BLoC / Cubit | BlocSignal |
| :--- | :--- | :--- |
| **Foundation** | Asynchronous Dart Streams | Synchronous Reactive Signals |
| **State Propagation** | Asynchronous (Microtask queue) | Immediate & Synchronous |
| **Rebuilding** | Tree-based rebuild filter (`buildWhen`) | Fine-grained reactivity (Signal updates) |
| **Lifecycle** | Manual close / Provider-driven | `SignalModel` lifecycle scope |

---

## 1. Migrating the Core State Container

### BLoC Migration (Events-in, States-out)

#### Before (Classic BLoC)
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

#### After (BlocSignal)
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

### Cubit Migration (Direct Method Calls)

In classic BLoC, a `Cubit` removes the event-mapping boilerplate to let you invoke methods that call `emit` directly. 

With `BlocSignal`, you can achieve the exact same behavior by setting the `Event` type parameter to `void` (or `dynamic`) and defining direct methods on your class:

#### Before (Classic Cubit)
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}
```

#### After (BlocSignal as a Cubit)
```dart
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends BlocSignal<void, int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}
```

---

## 2. Migrating UI Providers

### Before (Classic `BlocProvider`)
```dart
BlocProvider(
  create: (context) => CounterBloc(),
  child: const CounterPage(),
)
```

### After (BlocSignalProvider)
```dart
BlocSignalProvider(
  create: (context) => CounterBloc(),
  child: const CounterPage(),
)
```

For injecting multiple blocs, replace `MultiBlocProvider` with `MultiBlocSignalProvider`:
```dart
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
    BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
  ],
  child: const AppShell(),
)
```

---

## 3. Migrating UI Builders & Listeners

### Before (Classic `BlocBuilder`)
```dart
BlocBuilder<CounterBloc, int>(
  builder: (context, state) {
    return Text('Count: $state');
  },
)
```

### After (BlocSignalBuilder)
```dart
BlocSignalBuilder<CounterBloc, int>(
  builder: (context, state) {
    return Text('Count: $state');
  },
)
```

---

## 4. Reading and Watching Blocs

### Before (Classic `context.read` / `context.watch`)
```dart
// Reading a bloc to trigger actions
context.read<CounterBloc>().add(Increment());

// Watching a state to rebuild the widget
final count = context.watch<CounterBloc>().state;
```

### After (BlocSignal context extensions)
```dart
// Reading a bloc to dispatch events (no rebuild dependency)
context.read<CounterBloc>().add(Increment());

// Watching a bloc (registers rebuild dependency on state changes)
final bloc = context.watch<CounterBloc>();
final count = bloc.stateValue;
```

---

## 5. Global Logging / Observation

### Before (Classic `BlocObserver`)
```dart
class MyObserver extends BlocObserver {
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print(transition);
  }
}
```

### After (BlocSignalObserver)
```dart
class MyObserver extends BlocSignalObserver {
  @override
  void onTransition(BlocSignal bloc, Object? event, Object? state) {
    print('State transitioned to: $state');
  }
}

void main() {
  BlocSignalObserver.observer = MyObserver();
}
```
