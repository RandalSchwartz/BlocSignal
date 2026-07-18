# bloc_signals

A synchronous state management library bridging the Business Logic Component (BLoC) pattern with a reactive signals foundation (using Rody Davis's `signals` package version 7).

This library combines the architectural predictability of the BLoC pattern (events go in, states come out) with the synchronous, glitch-free, and highly precise reactivity of signals.

---

## Features

- ⚡ **Synchronous & Glitch-Free**: Eliminates microtask-queue latency. State updates propagate instantly inside the current execution frame.
- 🎯 **Fine-Grained Reactivity**: Built directly on Rody Davis's signals v7 primitives.
- 🧹 **Lifecycle-Safe**: Hooks into a `SignalModel` scope to automatically clean up downstream effects and subscriptions on `.close()`.
- 🔍 **Global Observer**: Register a `BlocSignalObserver` to log, monitor, and inspect all transitions and errors across your application.

---

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  bloc_signals: ^0.1.0
```

Or run:

```bash
dart pub add bloc_signals
```

---

## Usage

### 1. Define Events & States
Define the events your component can receive and the shape of the state it emits:

```dart
sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}
```

### 2. Implement the BlocSignal
Extend `BlocSignal` and override `onEvent` to handle incoming events and emit states synchronously:

```dart
import 'package:bloc_signals/bloc_signals.dart';

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    switch (event) {
      case Increment():
        emit(stateValue + 1);
      case Decrement():
        emit(stateValue - 1);
    }
  }
}
```

### 3. Observe Globally
Set up a custom observer to track events and state transitions:

```dart
class ConsoleObserver extends BlocSignalObserver {
  @override
  void onEvent(BlocSignal<dynamic, dynamic> bloc, Object? event) {
    print('Event added: $event');
  }

  @override
  void onTransition(BlocSignal<dynamic, dynamic> bloc, Object? event, Object? state) {
    print('State transitioned to: $state');
  }
}

void main() {
  BlocSignalObserver.observer = ConsoleObserver();

  final bloc = CounterBloc();
  bloc.add(Increment()); // Triggers print: State transitioned to: 1
  bloc.close();
}
```

---

## Integration with Flutter

If you are building a Flutter application, use [bloc_signals_flutter](https://pub.dev/packages/bloc_signals_flutter) for UI bindings, dependency injection providers, and rebuild builders.

For migration help from classic BLoC, check out our [Migration Guide](../MIGRATION.md).

---

## Credits & Acknowledgements

This package is heavily inspired by and builds upon the original **[bloc](https://pub.dev/packages/bloc)** library by **[Felix Angelov](https://github.com/felangel)**, combined with the reactive primitives of the **[signals](https://pub.dev/packages/signals)** library by **[Rody Davis](https://github.com/roddydavis)**.

