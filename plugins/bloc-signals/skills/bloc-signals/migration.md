# Migration Guide: From classic `bloc` to `BlocSignal`

This guide explains how to migrate your Flutter and Dart applications from classic BLoC (`package:bloc` and `package:flutter_bloc`) to `BlocSignal` (`package:bloc_signals` and `package:bloc_signals_flutter`).

## 🚀 Progressive Migration Strategy (Zero All-at-Once Rewrite)

You don't need to rewrite your entire application at once! `bloc_signals` provides built-in stream interop extensions so you can adopt `BlocSignal` incrementally:

### 1. Wrapping Legacy BLoCs into `BlocSignal` Containers
Wrap any existing classic BLoC or Cubit stream into a `BlocSignal` container to use `BlocSignalBuilder` or reactive signals immediately without changing your existing BLoC code:

```dart
final legacyBloc = LegacyCounterBloc();

// Convert legacy BLoC stream into a BlocSignal container
final blocSignal = legacyBloc.stream.toBlocSignal(
  initialState: legacyBloc.state,
);

// Consume in reactive BlocSignalBuilder or signals UI!
BlocSignalBuilder<StreamBlocSignal<int>, int>(
  bloc: blocSignal as StreamBlocSignal<int>,
  builder: (context, count) => Text('Count: $count'),
);
```

### 2. Consuming `BlocSignal` in Legacy Stream / `BlocBuilder` Widgets
If you convert a state container to `BlocSignal` but want to keep existing UI widgets unchanged during early migration, use `.toStream()` or `.stream`:

```dart
final myBlocSignal = CounterBloc();

// Consume in legacy StreamBuilder or Stream widgets
// Note: Store stream reference in initState or a State field so StreamBuilder identity remains stable across builds.
late final stream = myBlocSignal.toStream();

StreamBuilder<int>(
  stream: stream,
  builder: (context, snapshot) => Text('${snapshot.data}'),
);
```

---

## Core Paradigm Shift: Streams vs. Signals


`BlocSignal` offers a synchronous, glitch-free alternative to classic BLoC while maintaining its core architectural predictability (events in, states out).

### Synchronous Propagation (No Microtask Delay)
Classic BLoC is built on Dart `Stream`s, which are asynchronous and rely on the Dart microtask queue. When you emit a state in classic BLoC, the UI rebuild is scheduled for the next frame. This can lead to transient "UI glitches" or race conditions when multiple states depend on one another.

In contrast, `BlocSignal` relies on reactive signals. State propagation is immediate and **synchronous**: calling `emit()` updates the state value instantly in the current execution block, recalculating the reactive dependency graph and triggering UI rebuilds in the exact same frame.

### Event Concurrency & Transformers

`BlocSignal` natively supports event concurrency transformers on `on<E>` handlers (similar to `package:bloc_concurrency`):

```dart
on<FetchPage>(
  (event, emit) async {
    final page = await api.fetchPage();
    emit(PageLoadSuccess(page));
  },
  transformer: droppable(), // or sequential(), restartable()
);
```

Available built-in transformers & concurrency utilities:
- **`droppable()`**: Drops incoming events while a handler for that event type is currently executing.
- **`sequential()`**: Queues incoming events and executes them sequentially in FIFO order via `Mutex`.
- **`restartable()`**: Allows new incoming events to supersede previous in-flight handler executions.
- **`Mutex`**: A zero-dependency async lock (`protect(() => ...)`) for custom synchronization.

In `BlocSignal`, track the active operation (e.g. using `CancelableOperation` from `package:async`) and cancel it synchronously when a new event is handled:
```dart
import 'package:async/async.dart';

class DetailBloc extends BlocSignal<DetailEvent, DetailState> {
  DetailBloc() : super(initialState: DetailInitial());
  CancelableOperation<DetailData>? _activeOperation;

  on<FetchDetails>((event, emit) async {
    await _activeOperation?.cancel();
    emit(DetailLoadInProgress());

    final operation = CancelableOperation.fromFuture(api.fetch(event.id));
    _activeOperation = operation;

    try {
      final data = await operation.value;
      if (!operation.isCanceled) {
        emit(DetailLoadSuccess(data));
      }
    } catch (e) {
      if (!operation.isCanceled) {
        emit(DetailLoadFailure(e));
      }
    }
  });

  @override
  Future<void> close() {
    _activeOperation?.cancel();
    return super.close();
  }
}
```

### Automatic State De-duplication
In classic BLoC, emitting the exact same state value multiple times will propagate downstream through the stream unless you filter it manually using `.distinct()`.

With `BlocSignal`, reactive signals automatically **de-duplicate equal values** (using `==` equality) at the primitive layer. If you call `emit()` with a state that is equal to the current state, downstream effects and UI builders will not be notified or rebuilt. This reduces redundant widget builds by default without requiring manual configuration.

### Custom Change-Definition Equality (`equals`)
In classic BLoC, filtering identical states requires adding `.distinct()` to streams or overriding `==` operator on state classes.

With `BlocSignal`, you can override `@protected bool equals(StateType previous, StateType current)` in your subclass (or pass an `equals:` callback to the constructor) to customize state de-duplication strategy (such as identity comparison `identical(previous, current)` or custom field matching) out-of-the-box:

```dart
class ReferenceCounterBloc extends BlocSignal<CounterEvent, CounterState> {
  ReferenceCounterBloc(CounterState initial) : super(initialState: initial);

  @override
  bool equals(CounterState previous, CounterState current) {
    return identical(previous, current); // Custom reference comparison
  }
}
```

To force classic BLoC stream behavior where **every single emit notifies observers** regardless of value equality, return `false`:

```dart
class AlwaysEmitBloc extends BlocSignal<CounterEvent, CounterState> {
  AlwaysEmitBloc(CounterState initial) : super(initialState: initial);

  @override
  bool equals(CounterState previous, CounterState current) => false; // Every emit notifies!
}
```

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

#### After (CubitSignal)
```dart
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}
```

---

## 2. Migrating UI Providers

Unlike classic `flutter_bloc` which internally depends on and re-exports `package:provider`, `bloc_signals_flutter` implements its own custom, hand-rolled `InheritedWidget` dependency injection nodes (`BlocSignalProvider` and `MultiBlocSignalProvider`). 

This means **you do not need to import or depend on `package:provider`** for scoping your blocs.

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

### Before (Classic `BlocListener`)
```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is Authenticated) {
      Navigator.pushNamed(context, '/home');
    }
  },
  child: const LoginForm(),
)
```

### After (BlocSignalListener)
```dart
BlocSignalListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is Authenticated) {
      Navigator.pushNamed(context, '/home');
    }
  },
  child: const LoginForm(),
)
```

### Before (Classic `BlocConsumer`)
```dart
BlocConsumer<CounterBloc, int>(
  listener: (context, state) {
    if (state == 10) showSnackbar(context, 'Limit!');
  },
  builder: (context, state) {
    return Text('Count: $state');
  },
)
```

### After (BlocSignalConsumer)
```dart
BlocSignalConsumer<CounterBloc, int>(
  listener: (context, state) {
    if (state == 10) showSnackbar(context, 'Limit!');
  },
  builder: (context, state) {
    return Text('Count: $state');
  },
)
```

### Before (Classic `BlocSelector`)
```dart
BlocSelector<CounterBloc, int, bool>(
  selector: (state) => state >= 10,
  builder: (context, isLimit) {
    return Text('Limit reached: $isLimit');
  },
)
```

### After (BlocSignalSelector)
```dart
BlocSignalSelector<CounterBloc, int, bool>(
  selector: (state) => state >= 10,
  builder: (context, isLimit) {
    return Text('Limit reached: $isLimit');
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

### Context Select (Selecting sub-state slices)

#### Before (Classic `context.select`)
```dart
final isEven = context.select<CounterBloc, bool>((bloc) => bloc.state.isEven);
```

#### After (BlocSignal `context.select`)
```dart
final isEven = context.select<CounterBloc, bool>((bloc) => bloc.stateValue.isEven);
```

---

## 5. Global Logging / Observation

### Before (Classic `BlocObserver`)
```dart
class MyObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    print('Created: $bloc');
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    print('Change: $change');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print('Transition: $transition');
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    print('Closed: $bloc');
  }
}
```

### After (BlocSignalObserver)
```dart
class MyObserver extends BlocSignalObserver {
  @override
  void onCreate(BlocSignalBase bloc) {
    super.onCreate(bloc);
    print('Created: $bloc');
  }

  @override
  void onChange(BlocSignalBase bloc, Change change) {
    super.onChange(bloc, change);
    print('Change: $change');
  }

  @override
  void onTransition(BlocSignalBase bloc, Object? event, Object? state) {
    super.onTransition(bloc, event, state);
    // Legacy support
  }

  @override
  void onClose(BlocSignalBase bloc) {
    super.onClose(bloc);
    print('Closed: $bloc');
  }
}
```

---

## 6. Listening to State Conditionally (`listenWhen`)

### Before (Classic `BlocListener` with `listenWhen`)
```dart
BlocListener<CounterBloc, int>(
  listenWhen: (previous, current) => current.isEven,
  listener: (context, state) {
    print('Even count: $state');
  },
  child: const CounterView(),
)
```

### After (BlocSignalListener with `listenWhen`)
```dart
BlocSignalListener<CounterBloc, int>(
  listenWhen: (previous, current) => current.isEven,
  listener: (context, state) {
    print('Even count: $state');
  },
  child: const CounterView(),
)
```

---

## 7. Composing Multiple Listeners

### Before (Classic `MultiBlocListener`)
```dart
MultiBlocListener(
  listeners: [
    BlocListener<AuthBloc, AuthState>(listener: (context, state) => ...),
    BlocListener<ThemeBloc, ThemeState>(listener: (context, state) => ...),
  ],
  child: const HomeScreen(),
)
```

### After (MultiBlocSignalListener)
```dart
MultiBlocSignalListener(
  listeners: [
    BlocSignalListener<AuthBloc, AuthState>(listener: (context, state) => ...),
    BlocSignalListener<ThemeBloc, ThemeState>(listener: (context, state) => ...),
  ],
  child: const HomeScreen(),
)
```

---

## ⚠️ Common Migration Gotchas & Pitfalls

### 1. Avoid Inline `.toStream()` Inside `build()`
Calling `myBlocSignal.toStream()` or `myBlocSignal.stream` directly inside Flutter's `build()` method creates a **new `Stream` object instance** on every rebuild. When `StreamBuilder.didUpdateWidget` checks `oldWidget.stream != widget.stream`, it sees a new instance, unsubscribes from the old stream, and re-subscribes, causing state resets.

```dart
// ❌ BAD: Creates a new stream instance on every build pass!
StreamBuilder<int>(
  stream: myBlocSignal.toStream(), 
  builder: (context, snapshot) => Text('${snapshot.data}'),
);

// ✅ GOOD: Cache the stream reference in initState() or a State field:
class _MyWidgetState extends State<MyWidget> {
  late final Stream<int> _stream = myBlocSignal.toStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }
}
```

### 2. Avoid Inline `.toBlocSignal(...)` Inside `build()`
Calling `legacyBloc.stream.toBlocSignal(initialState: legacyBloc.state)` creates an active `StreamSubscription` under the hood. Instantiating it inside `build()` will leak a new stream subscription on every widget rebuild.

```dart
// ❌ BAD: Leaks stream subscriptions on every build pass!
Widget build(BuildContext context) {
  final blocSignal = legacyBloc.stream.toBlocSignal(initialState: legacyBloc.state);
  return BlocSignalBuilder(...);
}

// ✅ GOOD: Instantiate once in initState() and close on dispose():
class _MyWidgetState extends State<MyWidget> {
  late final BlocSignalBase<int> _blocSignal;

  @override
  void initState() {
    super.initState();
    _blocSignal = widget.legacyBloc.stream.toBlocSignal(
      initialState: widget.legacyBloc.state,
    );
  }

  @override
  void dispose() {
    _blocSignal.close(); // Cleanly cancels stream subscription
    super.dispose();
  }
}
```
