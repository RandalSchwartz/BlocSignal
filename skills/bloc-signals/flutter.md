# BlocSignal Flutter Integration

This guide details how to consume, scope, and bind `BlocSignal` states in a Flutter application.

---

## ⚡ Reacting to State changes with `BlocSignalBuilder`

`BlocSignalBuilder` is a widget that rebuilds dynamically whenever the state of the provided `BlocSignal` changes.

```dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<CounterBloc, int>(
      builder: (context, state) {
        return Text('Count: $state');
      },
    );
  }
}
```

* **Dynamic Subscriptions**: It hooks up to signals internally, automatically unsubscribing when the widget is unmounted.
* **Context Lookup**: If the `bloc` parameter is omitted, it will automatically lookup the closest instance of `CounterBloc` provided via `BlocSignalProvider` in the widget tree.

---

## 🏗️ Scoping Blocs with `BlocSignalProvider`

`BlocSignalProvider` acts as a dependency injection widget, providing a `BlocSignal` instance to its children down the widget tree.

```dart
BlocSignalProvider<CounterBloc>(
  create: (context) => CounterBloc(),
  child: const CounterScreen(),
)
```

### Accessing the Bloc from Context
You can retrieve the provided bloc using:
* `BlocSignalProvider.of<T>(context)`
* Or standard Flutter context lookups.

## 🔄 StatefulWidget Lifecycle Integration

When using `StatefulWidget` (or `SignalStatefulWidget`), you can safely instantiate long-lived `computed` signals and register side-effect `effect`s. Because `initState` runs exactly once, this avoids frame-by-frame subscription churn.

> [!NOTE]
> **Do I still need to dispose effects in a `SignalStatefulWidget`?**
> **Yes.** While `SignalStatefulWidget` automatically manages reactivity for the `build` method, it has no automatic way of tracking raw `effect()` instances registered inside `initState()`. You must always manually dispose of them. (The only exception is when using Flutter Hooks `HookWidget` + `signals_hooks`, where `useSignalEffect` handles unmount disposal automatically).

### The Stateful Pattern
1. **Initialize in `initState`**: Instantiate `computed` properties and register `effect` callbacks.
2. **Dispose in `dispose`**: You **must** call the returned dispose callback of any `effect` inside the widget's `dispose()` lifecycle method to prevent memory leaks.


```dart
class CounterWatcher extends StatefulWidget {
  const CounterWatcher({super.key});

  @override
  State<CounterWatcher> createState() => _CounterWatcherState();
}

class _CounterWatcherState extends State<CounterWatcher> {
  late final CounterCubit _cubit;
  late final ReadOnlySignal<bool> _isEven;
  late final void Function() _disposeEffect;

  @override
  void initState() {
    super.initState();
    _cubit = CounterCubit();
    
    // Safely initialize computed once
    _isEven = computed(() => _cubit.stateValue % 2 == 0);
    
    // Safely register effect once
    _disposeEffect = effect(() {
      print('Current isEven: ${_isEven.value}');
    });
  }

  @override
  void dispose() {
    // Clean up the effect to prevent memory leaks
    _disposeEffect();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<CounterCubit, int>(
      bloc: _cubit,
      builder: (context, count) {
        return Text('Even? ${_isEven.value}');
      },
    );
  }
}
```

---

## 🪝 Flutter Hooks Integration (signals_hooks)

If your project uses `flutter_hooks` and `signals_hooks`, you can consume `BlocSignal` states cleanly inside a `HookWidget`. This completely removes the need for `StatefulWidget` boilerplate or manual effect disposal, as the hook lifecycle automatically handles resource teardown on unmount.

### Example Hook Usage
* **`useSignalValue`**: Directly reads and subscribes to the `bloc.state` signal. Rebuilds the `HookWidget` automatically when state changes.
* **`useSignalEffect`**: Registers a side effect that automatically disposes when the widget is unmounted.
* **`useComputed`**: Creates a derived computed signal whose lifecycle is managed by the hook.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'my_counter_bloc.dart';

class CounterHookScreen extends HookWidget {
  final CounterCubit cubit;
  const CounterHookScreen({required this.cubit, super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Automatically read and subscribe to the state signal
    final count = useSignalValue(cubit.state);

    // 2. Safely compose derived state inside the hook
    final isEven = useComputed(() => count % 2 == 0);

    // 3. Register a side-effect that auto-disposes on unmount
    useSignalEffect(() {
      print('Current state value: $count, isEven: ${isEven.value}');
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Count: $count'),
            Text('Is Even? ${isEven.value}'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => cubit.increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## 💡 Performance Guidelines

1. **Prefer `BlocSignalBuilder`**: Instead of watching signals directly using context watches, encapsulate the target builder UI in `BlocSignalBuilder`. This limits widget rebuild scopes.
2. **Never Call `effect()` or `computed()` Inside Build Methods**: 
   * Accessing `.value` inside a builder registers reactive dependencies implicitly and safely.
   * Calling `effect()` inside `build()` spawns a new listener on every build frame, creating a severe memory leak.
   * Calling `computed()` inside `build()` forces the dependency graph to re-evaluate and allocate nodes on every frame. 
   * **Rule**: Keep `build` methods pure. Define `computed` and `effect` properties inside Cubit/Bloc constructors, or in a `StatefulWidget`'s `initState` lifecycle.

