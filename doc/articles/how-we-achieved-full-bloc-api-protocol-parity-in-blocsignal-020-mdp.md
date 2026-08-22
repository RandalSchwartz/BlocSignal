---
series: "BlocSignal Architecture & Practice"
title: "How We Achieved Full BLoC API & Protocol Parity in BlocSignal 0.2.0"
published: true
description: "A deep dive into bridging the classic BLoC/Cubit pattern with the synchronous, reactive power of signals in Flutter & Dart."
tags: flutter, dart, statemanagement, signals
canonical_url: https://dev.to/randalschwartz/how-we-achieved-full-bloc-api-protocol-parity-in-blocsignal-020
---

The BLoC (Business Logic Component) pattern is one of the most reliable and trusted state management architectures in the Flutter ecosystem. By separating event inputs from state outputs, it provides outstanding predictability, trace-ability, and testability.

However, classic BLoC is built entirely on asynchronous Dart `Stream`s. While powerful, streams run on the microtask queue, which introduces frame-level delays and can lead to transient UI glitches or coordination issues when chaining multiple reactive nodes.

Enter **`BlocSignal`**—a state management library that bridges the structural discipline of BLoC with the synchronous, glitch-free, fine-grained rebuild performance of **reactive signals**.

In the **0.2.0 release**, we set out to achieve complete class and protocol parity with classic BLoC (`package:bloc` and `package:flutter_bloc`), making it seamless to migrate or pair-program using familiar paradigms. 

Here is how we did it, including how we solved complex element-caching leaks and the few necessary exceptions we made due to the nature of signals.

---

## 1. Core Observability: Changes, Transitions, and Observers

Classic BLoC provides a robust global `BlocObserver` that tracks the lifecycle, events, transitions, and errors of every bloc in the app. In `BlocSignal 0.2.0`, we implemented the exact same observability protocol:

```dart
// The Change class tracks state mutations (used by both Blocs and Cubits)
final change = Change(currentState: oldState, nextState: newState);

// The Transition class tracks event-triggered updates (used by Blocs)
final transition = Transition(
  currentState: oldState,
  event: IncrementEvent(),
  nextState: newState,
);
```

### Global Interception
You can now subclass `BlocSignalObserver` and hook into every lifecycle phase across your application:

```dart
class MyObserver extends BlocSignalObserver {
  @override
  void onCreate(BlocSignalBase bloc) {
    print('Created: ${bloc.runtimeType}');
  }

  @override
  void onChange(BlocSignalBase bloc, Change change) {
    print('Change in ${bloc.runtimeType}: $change');
  }

  @override
  void onTransition(BlocSignalBase bloc, Object? event, Object? state) {
    // Legacy support
  }

  @override
  void onClose(BlocSignalBase bloc) {
    print('Closed: ${bloc.runtimeType}');
  }
}
```

### Local Overrides
We also aligned subclass method signatures so you can override `onChange(Change)` and `onTransition(Transition)` directly in your custom blocs to execute local side-effects, logging, or analysis:

```dart
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onChange(Change<int> change) {
    super.onChange(change); // Keep observer updated
    print('Local change detected: $change');
  }
}
```

---

## 2. Flutter Bindings Parity

To bring `bloc_signals_flutter` to full parity, we overhauled the widget lifecycle behaviors to match `flutter_bloc` 1:1.

### Lazy Provider Initialization
In previous versions, `BlocSignalProvider` eagerly created the BLoC on mount. In `0.2.0`, we aligned with classic BLoC by defaulting to `lazy: true`. The BLoC's `create` factory is deferred until the first time a descendant widget looks up the bloc (via `context.read()`, `context.watch()`, or builders).

```dart
BlocSignalProvider(
  create: (context) => HeavyLoadingBloc(),
  lazy: true, // Deferred until accessed
  child: const MyWidget(),
)
```

### Conditional Listening (`listenWhen`)
We added the `listenWhen` filter parameter to `BlocSignalListener` and `BlocSignalConsumer`. This allows developers to conditionally filter listener triggers based on the `previous` and `current` states:

```dart
BlocSignalListener<CounterBloc, int>(
  listenWhen: (previous, current) => current.isEven,
  listener: (context, state) {
    // Only runs when the count changes to an even number
    showCelebrationDialog(context);
  },
  child: const CounterView(),
)
```

We also implemented **`MultiBlocSignalListener`**, letting you chain multiple independent listeners linearly to keep your widget trees flat and readable.

---

## 3. Solving the `context.select` Memory Leak (Under the Hood)

Implementing `context.select<T, R>(selector)` with reactive signals was our greatest technical challenge. 

In classic BLoC, `context.select` listens to a stream and rebuilds the calling widget element *only* when the selected sub-state changes. With signals, we wanted to use a `Computed` signal to wrap the selector callback and rebuild the calling `Element` whenever the computed signal value changed.

To make this O(1), we used an `Expando` keyed on the calling `Element` to store and reuse `_SelectSubscription` objects across builds.

### The Bug: Strong Reference Cycle Leak
An `Expando` uses weak keys, meaning entries are automatically garbage-collected when the key (`Element`) is no longer referenced. 

However, our initial implementation of the `effect` callback captured a strong reference to the `Element` to trigger `element.markNeedsBuild()`. Because the `effect` was reachable from the subscription stored in the `Expando`, this created a strong reference cycle:
`Element (Key) -> SelectorState -> Subscription -> Effect -> Element (Key)`.

This cycle prevented the `Element` key from ever being garbage-collected, creating a massive memory leak!

### The Fix: `WeakReference` to the Rescue
To break this cycle, we wrapped the `Element` in a `WeakReference` inside our subscription model:

```dart
class _SelectSubscription<T extends BlocSignalBase<dynamic>, R> {
  _SelectSubscription({
    required T bloc,
    required R Function(T) selector,
    required Element element,
  })  : _bloc = bloc,
        _selector = selector,
        _elementRef = WeakReference(element) {
    _computed = computed(() => _selector(_bloc));
    _selectedValue = _computed.value;

    _dispose = effect(() {
      final newValue = _computed.value;
      if (newValue != _selectedValue) {
        _selectedValue = newValue;
        final el = _elementRef.target;
        if (el != null && el.mounted) {
          el.markNeedsBuild();
        }
      }
    });
  }
  // ...
}
```

Now, the closure only holds a weak reference to the element. Once the widget unmounts, the `Element` key is naturally garbage-collected, which automatically evicts the subscription from the `Expando` and cleans up the reactive effect!

---

## 4. Necessary Exceptions (Because of Streams)

While we achieved API parity, there are a few features from classic BLoC that **cannot** be replicated directly due to the underlying shift from Streams to Signals. 

Here is what is missing, and how to achieve the same result using signals:

### 1. Custom `EventTransformer`s
Classic BLoC lets you supply custom event transformers (like `concurrent`, `sequential`, or `restartable` from `package:bloc_concurrency`) to control how events queue up. Because `BlocSignal` executes event handlers synchronously upon dispatch, there is no event queue stream.

* **droppable (Throttle) Equivalent**: If you want to drop events while an async action is running, check your loading state synchronously:
  ```dart
  on<FetchPage>((event, emit) async {
    if (stateValue is PageLoadInProgress) return; // Drop event
    emit(PageLoadInProgress());
    // ...
  });
  ```

* **restartable (SwitchMap) Equivalent**: If you want to cancel the current request when a new event arrives, track a `CancelableOperation` and cancel it:
  ```dart
  class DetailBloc extends BlocSignal<DetailEvent, DetailState> {
    CancelableOperation<Data>? _activeOperation;

    on<FetchDetails>((event, emit) async {
      await _activeOperation?.cancel(); // Cancel active operation
      emit(DetailLoadInProgress());
      
      final op = CancelableOperation.fromFuture(api.fetch(event.id));
      _activeOperation = op;
      
      final data = await op.value;
      if (!op.isCanceled) emit(DetailLoadSuccess(data));
    });
  }
  ```

### 2. Debouncing Events
In classic BLoC, you might debounce event dispatching (e.g. search box text entry). In `BlocSignal`, you can achieve this by managing a simple `Timer` in your bloc:

```dart
class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
  Timer? _debounceTimer;

  @override
  Future<void> onEvent(SearchEvent event) async {
    await super.onEvent(event);
    if (event is SearchTextChanged) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(event.query);
      });
    }
  }
}
```

---

## Bonus: Automated Migrations with AI Coding Skills

We know that refactoring state management across a large codebase can be daunting. To solve this, the `bloc_signals` repository exposes a built-in **AI Coding Skill** under [`skills/bloc-signals/migration.md`](https://github.com/RandalSchwartz/BlocSignal/blob/main/skills/bloc-signals/migration.md).

This markdown document is structured specifically for LLMs and AI coding assistants (like Google Antigravity, Cursor, or Copilot). By pointing your AI agent to this skill, it can automatically rewrite and migrate your legacy stream-based BLoC widgets and state classes to reactive signals with high precision, eliminating almost all of the manual migration friction!

---

## Conclusion

With `BlocSignal 0.2.0`, you no longer have to choose between the architectural predictability of BLoC and the raw performance of reactive signals. By achieving class and protocol parity, you get the best of both worlds: O(1) state selections, synchronous propagation, full observer tracing, and zero frame-level rebuild delays.

Check out the packages today on pub.dev:
👉 **[bloc_signals](https://pub.dev/packages/bloc_signals)**  
👉 **[bloc_signals_flutter](https://pub.dev/packages/bloc_signals_flutter)**
