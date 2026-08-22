---
series: "BlocSignal Architecture & Practice"
title: "BLoC meets Signals: How to Pitch BlocSignal to Your Dev Leads"
published: true
description: "Introducing a new state manager to a Flutter team is hard. Here is how to handle the tough architectural reviews for BlocSignal (BLoC + Signals)."
tags: flutter, dart, statemanagement, architecture
---

Flutter state management is a battleground. Every few seasons, a new paradigm emerges, claiming to solve all our development woes. We’ve seen standard `setState`, scoped model, Provider, BLoC, MobX, and Riverpod. 

Recently, **Signals** (derived from the Preact architecture) has taken the frontend world by storm. It offers synchronous, fine-grained, and glitch-free reactivity. But raw signals can feel too chaotic for large teams, leading developers to modify state directly from the UI without any structure.

Enter **BlocSignal**—a framework that bridges the architectural discipline of the BLoC pattern (Events in, States out) with the extreme performance and synchronous reactivity of Signals. 

But when you bring a new library to an architectural review board, you will face pushback. Here is how to pitch **BlocSignal** and answer the 5 toughest questions your dev leads and reviewers will throw at you.

---

## Objection 1: "It's brand new! Why should we adopt an untested library?"

### The Critic
> "We can't afford to run our production apps on a brand-new, untested state-management library. What if it gets abandoned or introduces critical bugs?"

### The Response
BlocSignal is a thin, architectural bridge linking two of the most mature, popular, and battle-tested paradigms in Dart and Flutter:

1. **The BLoC Pattern**: Originally designed by Google and popularized by Felix Angelov, the BLoC model (Events, States, Cubits, and standard unidirectional data flow) has been the gold standard for enterprise Flutter for years. Developers use the exact same mental models they already know.
2. **Preact-style Signals**: The reactivity engine is powered by Rody Davis's `signals` library (version 7). Signals are the industry-standard state primitive of modern web frameworks like SolidJS, Qwik, Angular, Vue, and Preact.
3. **100% Test Coverage**: The `bloc_signals` and `bloc_signals_flutter` packages maintain **100% line coverage** for all codebase paths. The API is locked down with strict automated unit and integration tests.

**Summary**: You aren't adopting a "from scratch" state engine; you are adopting a structured interface wrapper over highly optimized, production-ready primitives.

---

## Objection 2: "We tried BLoC and moved to Riverpod. Why go back?"

### The Critic
> "We migrated from BLoC to Riverpod because we hated streams, microtask queues, visual rendering lag, and boilerplate. Why would we go back to BLoC?"

### The Response
BlocSignal solves the exact pain points that drove teams to Riverpod in the first place, while avoiding Riverpod's own drawbacks:

* **Synchronous Updates**: Unlike classic BLoC which propagates state changes asynchronously via Dart `Stream` microtask queues, BlocSignal propagates updates **synchronously** in the same frame. Just like Riverpod, calling `emit()` instantly notifies downstream listeners.
* **Widget-Tree Scoped Lifecycle**: Riverpod relies on global provider scopes. Scoping state to specific routes, dialogs, or subtrees requires complex caching or parameter bindings. BlocSignal restores Flutter's native dependency injection model using `BlocSignalProvider` (built on `InheritedWidget`). When a widget unmounts, the bloc's resources are automatically closed.
* **No Stream Boilerplate**: Instead of using complex RxDart stream operations to derive state, you can declare lightweight, cached, and automatically updated derived values using `computed()` signals inside your constructor:
  ```dart
  late final ReadOnlySignal<bool> isCartEmpty = computed(() => stateValue.items.isEmpty);
  ```
* **Automatic De-duplication**: Classic BLoC triggers transition listeners for every emit. BlocSignal de-duplicates equal states (`==`) out of the box, preventing redundant widget rebuilds.

---

## Objection 3: "It's not enterprise battle-ready."

### The Critic
> "Enterprise apps need logging, metrics, error tracking, and strict guidelines. Lightweight state libraries are toys that don't scale."

### The Response
BlocSignal was built from day one with enterprise constraints in mind:

1. **Native OpenTelemetry (OTel) Observability**: In enterprise environments, tracing requests across systems is vital. BlocSignal includes `OtelBlocSignalObserver` which:
   - Automatically tracks event transitions, asynchronous executions, and errors.
   - Maps them directly to OpenTelemetry Spans.
   - Implements bounded span caching (capped at 1000 items, evicting oldest) to guarantee zero memory leaks.
2. **Failure Safety**: Event registry zones capture handler exceptions without disrupting the state container lifecycle, routing them dynamically to telemetry observers.
3. **Strict Quality Rules**: The project enforces strict `very_good_analysis` lints (the enterprise-standard ruleset in Flutter) and 100% doc comment coverage.

---

## Objection 4: "Why not just use raw Signals? What is the value of wrapping them in BLoC?"

### The Critic
> "If we already have access to the `signals` package, why introduce BLoC? Can't we just use raw signal objects inside plain controller classes?"

### The Response
Raw signals provide fine-grained reactivity but lack architectural discipline. In large team environments, raw mutable signals can lead to spaghetti state management:

* **Enforced Unidirectional Data Flow**: With raw signals, widgets can read and write to signals directly from anywhere (e.g. `counter.value++` inside a button). BlocSignal enforces a clear event-driven boundary: widgets can only dispatch events via `.add()`, and the container's state is exposed as a `ReadonlySignal`, meaning **only the bloc can call `emit()`**.
* **Traceability**: Because mutations are routed through discrete events, we can observe, trace, and debug transitions globally (e.g., via OpenTelemetry), which is impossible with raw, ad-hoc signal changes.
* **Uniformity**: It provides a unified pattern for teams. Instead of every developer building custom notifier/controller classes in their own style, everyone inherits from `BlocSignal` or `Cubit` patterns, ensuring consistency across feature modules.

---

## Objection 5: "How do we coordinate overlapping asynchronous events? (Loss of `bloc_concurrency`)"

### The Critic
> "Standard BLoC uses stream concurrency transformers like `restartable()` or `droppable()` to cancel or queue overlapping events of the same type. How do we achieve these essential concurrent behaviors without streams?"

### The Response
While classic BLoC utilizes RxDart stream transformers, BlocSignal allows teams to orchestrate concurrency through native Dart async patterns, signal effects, or light-weight guard clauses.

1. **Concurrent Execution by Default**: If multiple handlers are invoked, they execute concurrently using `Future.wait` orchestration under the hood, ensuring no tasks are blocked.
2. **Simple Declarative Guards**: Implementing concurrency strategies like `droppable` is trivial. For instance, we can check a loading state before executing the business logic:
   ```dart
   on<LoadData>((event, emit) async {
     if (stateValue is DataLoading) return; // Droppable pattern
     emit(DataLoading());
     // Fetch data...
   });
   ```
3. **Cancellation (Restartable Pattern)**: To replicate a `restartable()` pattern (where a new event cancels the previous active task), keep a reference to a cancellation token or active future inside the bloc:
   ```dart
   CancelableOperation? _activeOperation;

   on<SearchQueryChanged>((event, emit) async {
     await _activeOperation?.cancel();
     _activeOperation = CancelableOperation.fromFuture(api.search(event.query));
     
     final results = await _activeOperation!.value;
     emit(SearchSuccess(results));
   });
   ```

---

## Feature Comparison Matrix

The table below summarizes the key trade-offs between the three main approaches:

| Feature | Classic BLoC (Streams) | Riverpod (v2/v3) | BlocSignal (Signals v7) |
| :--- | :--- | :--- | :--- |
| **Propagation** | Asynchronous (Microtask) | Synchronous | **Synchronous** |
| **Dependency Injection** | Widget Tree Scoped | Global Scopes / `ref` | **Widget Tree Scoped** |
| **State De-duplication** | Manual (`distinct()`) | Automatic | **Automatic (`==`)** |
| **Derived State** | Complex (RxDart / Streams) | Declarative (`ref.watch`) | **Declarative (`computed`)** |
| **Lifecycle Hook** | Manual / `BlocProvider` | Auto-Dispose (`ref.keepAlive`) | **Automatic (Unmount / `close`)** |
| **Observability** | `BlocObserver` (Local) | `ProviderObserver` (Local) | **OTel Tracing (`OtelObserver`)** |
| **Test Overhead** | High (Stream queues) | Medium (`ProviderContainer`) | **Low (Synchronous Asserts)** |

---

## Conclusion

BlocSignal is the evolution of two great state management philosophies. It offers the **safety and scale** of BLoC combined with the **developer experience and speed** of Signals. 

Have you tried bridging these patterns in your Flutter apps? Let me know in the comments below!
