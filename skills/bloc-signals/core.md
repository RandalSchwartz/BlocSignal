# BlocSignal Core Guidelines & FAQ

This document outlines core synchronous concepts, de-duplication behaviors, and common FAQs for using `bloc_signals`.

---

## 🏗️ Core Architecture & Behaviors

1. **Synchronous Propagation**: Updates via `emit(newState)` propagate **synchronously**. Downstream recalculations and widget rebuilds occur in the exact same frame.
2. **Automatic De-duplication**: Signals automatically de-duplicate identical states using `==` equality. If you call `emit()` with a state equal to the current state, downstream effects and builders will **not** trigger.
3. **Lifecycle & Disposal (`isClosed`)**: Calling `close()` disposes of the underlying `SignalModel` effect tracking and marks the bloc as closed (`isClosed = true`). Subsequent events or emits are dropped.
4. **Stream Transformations**: Standard stream-transformer properties (e.g. `debounce`, `throttle`) are not available. Use custom timing triggers or signals utilities.

---

## ❓ FAQ & Common Patterns

### 1. Sealed Classes and Event/State Exhaustiveness

#### Q: If the event or state class of a `BlocSignal` is a `sealed` class, is there an exhaustiveness check for `.on<T>` blocks?
**A:** No. Because `.on<T>` handles event registration dynamically at runtime (by adding handlers to an internal registry list during constructor initialization), the Dart compiler cannot statically analyze or enforce exhaustiveness checks on these registration blocks.

#### How to get compile-time safety:
If you want the compiler to guarantee that every subclass of a sealed `Event` class is explicitly handled, override `onEvent(Event event)` directly in your subclass and use a Dart `switch` statement or a `switch` expression. The compiler will then enforce full exhaustiveness checks:

##### Option A: Switch Statement (switch-case)
```dart
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  FutureOr<void> onEvent(CounterEvent event) {
    // The compiler will throw an error if any subclass of CounterEvent is not handled.
    switch (event) {
      case Increment():
        emit(stateValue + 1);
      case Decrement():
        emit(stateValue - 1);
    }
  }
}
```

##### Option B: Switch Expression
```dart
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  FutureOr<void> onEvent(CounterEvent event) {
    // Highly readable; compiler enforces that every branch evaluates to a state
    final nextState = switch (event) {
      Increment() => stateValue + 1,
      Decrement() => stateValue - 1,
    };
    emit(nextState);
  }
}
```


---

### 2. Using Signals Utilities (`effect`, `computed`)

#### Q: How do I use `effect()` and `computed()` with a `BlocSignal`, both inside the constructor and as a consumer?
**A:** `aBlocSignal.state` exposes a `ReadonlySignal<StateType>` directly. This allows you to integrate with all core `signals` primitives seamlessly.

#### ── In the Constructor (Internal) ──
Declaring reactive primitives directly within the `BlocSignal` subclass constructor is ideal for encapsulation and automatic lifecycle management.

* **`effect` in the Constructor**: Declaring an `effect` inside the constructor automatically registers and disposes of the effect correctly when the bloc is closed (via `close()`):
  ```dart
  class LoggingCounterCubit extends CubitSignal<int> {
    LoggingCounterCubit() : super(initialState: 0) {
      // Registered and scoped automatically to the Cubit's lifecycle
      effect(() {
        print('Transitioned to state: $stateValue');
      });
    }
    
    void increment() => emit(stateValue + 1);
  }
  ```

* **`computed` in the Constructor**: Define a `late final ReadonlySignal<T>` to hold the derived signal, and initialize it inside the constructor by referencing `state`:
  ```dart
  class CounterCubit extends CubitSignal<int> {
    late final ReadOnlySignal<int> tripleValue;
  
    CounterCubit() : super(initialState: 1) {
      tripleValue = computed(() => state() * 3);
    }
  
    void increment() => emit(stateValue + 1);
  }
  ```

#### ── As a Consumer (External) ──
Consumers who hold an instance of a `BlocSignal` can read and react to state changes externally.

* **`effect` as a Consumer**: An external consumer can register an effect on `bloc.state`. Since it is registered externally, the consumer **must manually dispose of the effect** when it is no longer needed to prevent memory leaks:
  ```dart
  final myBloc = CounterCubit();
  
  // Create effect and keep dispose function
  final dispose = effect(() {
    print('Consumer received new state: ${myBloc.state()}');
  });
  
  // Clean up manually when done (e.g. on widget dispose)
  dispose();
  ```
  > [!IMPORTANT]
  > **This is NOT necessary when using Flutter UI builders (`BlocSignalBuilder`, `SignalBuilder`, or inheriting from `SignalWidget`).** 
  > These widgets manage the subscription lifecycle internally and automatically unsubscribe when the widget is unmounted from the tree. You do not need to call `effect` inside UI build methods; simply reading the signal's value triggers automatic rebuilds. In fact, calling `effect()` inside a `build` method is a performance anti-pattern.

* **`computed` as a Consumer**: Consumers can derive their own computed values using `bloc.state` or any custom computed signals exposed by the bloc:
  ```dart
  final myBloc = CounterCubit();
  
  // Create consumer-level computed signal
  final isStateEven = computed(() {
    return myBloc.state() % 2 == 0;
  });
  ```
