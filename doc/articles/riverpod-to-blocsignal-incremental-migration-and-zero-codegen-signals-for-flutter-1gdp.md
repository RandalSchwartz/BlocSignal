---
title: Riverpod to BlocSignal: Incremental Migration and Zero-Codegen Signals for Flutter
published: true
description: Learn how to trial or incrementally migrate from Riverpod to BlocSignal with zero code generation, fine-grained signal graph reactivity, and bidirectional interop.
tags: flutter, dart, riverpod, statemanagement
canonical_url: https://blocsignal.dev
series: BlocSignal Architecture & Practice
---

## Introduction: Combining Riverpod Safety with Zero Codegen

If you've been building Flutter apps with **Riverpod**, you already know the joy of compile-time provider safety, auto-disposal, and synchronous notification propagation via `ProviderListenable`. Riverpod fundamentally raised the bar for Flutter state management.

However, as projects grow, many Riverpod developers run into familiar friction points:
* **Code Generation Overhead**: Depending heavily on `riverpod_generator` and waiting on `build_runner` watches during rapid UI iteration.
* **Complex Provider Trees**: Managing nested `ProviderScope` overrides and `.family` cache eviction policies when scaling large teams.
* **All-or-Nothing Migration Concerns**: Wanting to trial new reactive primitives or event-driven BLoC architectures without rewriting an entire codebase.

What if you could combine the compile-time safety and synchronous reactivity you love in Riverpod with **zero code generation**, **fine-grained signal graph reactivity**, and the ability to **trial or migrate incrementally screen-by-screen**?

Enter **BlocSignal** and **`bloc_signals_riverpod`**.

---


## The Core Ergonomics: Riverpod `Notifier` vs. `CubitSignal`

Let's compare the classic **Todos** application—one of the benchmark examples in the official Riverpod monorepo—ported directly to `BlocSignal`.

### The Riverpod Approach (Requires `@riverpod` & `build_runner`)

In modern Riverpod, creating a todo list with reactive filtering typically involves a generated `Notifier` and separate provider getters or `ref.watch` selectors:

```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  List<Todo> build() => const [];

  void addTodo(String description) {
    state = [...state, Todo(id: DateTime.now().toString(), description: description)];
  }

  void toggle(String id) {
    state = [
      for (final todo in state)
        if (todo.id == id) todo.copyWith(completed: !todo.completed) else todo
    ];
  }
}

// Derived filter provider
@riverpod
List<Todo> filteredTodos(Ref ref) {
  final todos = ref.watch(todoListProvider);
  final filter = ref.watch(todoFilterProvider);
  return switch (filter) {
    TodoFilter.all => todos,
    TodoFilter.active => todos.where((t) => !t.completed).toList(),
    TodoFilter.completed => todos.where((t) => t.completed).toList(),
  };
}
```

### The BlocSignal Approach (100% Pure Dart 3, No Codegen)

With `BlocSignal`, your state container is a standard handwritten Dart class (`CubitSignal<List<Todo>>`). Reactive derivations like `filteredTodos` and `uncompletedCount` are declared inline using **signals `computed()`**:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:signals_core/signals_core.dart';

class TodosCubit extends CubitSignal<List<Todo>> {
  // Pass `equals: listEquals` to enforce value-based list equality for state de-duplication!
  TodosCubit([List<Todo> initialTodos = const []])
      : super(initialState: initialTodos, equals: listEquals) {
    // 1. Reactive filter signal
    filter = signal(TodoFilter.all);

    // 2. Synchronously derived computed signals
    filteredTodos = computed(() {
      return switch (filter.value) {
        TodoFilter.all => stateValue,
        TodoFilter.active => stateValue.where((t) => !t.completed).toList(),
        TodoFilter.completed => stateValue.where((t) => t.completed).toList(),
      };
    });

    uncompletedCount = computed(() => stateValue.where((t) => !t.completed).length);
  }

  late final Signal<TodoFilter> filter;
  late final ReadonlySignal<List<Todo>> filteredTodos;
  late final ReadonlySignal<int> uncompletedCount;

  void addTodo(String description) {
    emit([...stateValue, Todo(id: DateTime.now().toString(), description: description)]);
  }

  void toggle(String id) {
    emit([
      for (final todo in stateValue)
        if (todo.id == id) todo.copyWith(completed: !todo.completed) else todo
    ]);
  }

  void setFilter(TodoFilter newFilter) => filter.value = newFilter;

  @override
  Future<void> close() async {
    filter.dispose();
    filteredTodos.dispose();
    uncompletedCount.dispose();
    await super.close();
  }
}
```

### What Changed?
1. **No `build_runner`**: No `.g.dart` generated files, no background watchers, no build step delays.
2. **Built-In Custom Equality (`equals: listEquals`)**: Because Dart `List` instances don't override `==` by default, passing `equals: listEquals` configures the underlying signal graph to de-duplicate state emissions based on list content equality.
3. **Fine-Grained Signal Graph**: Updates to `filter.value` or calling `emit(...)` re-evaluate `computed()` derivations synchronously and notify only dependent widgets.
4. **Explicit Container Lifecycles**: Disposing the cubit disposes its internal signals automatically.


---

## Zero Risk: Incremental Trial & Bidirectional Interop

You do **not** need to rewrite your application to try `BlocSignal`. With the `bloc_signals_riverpod` package, you can seamlessly bridge the two frameworks in both directions.

```yaml
dependencies:
  bloc_signals: ^1.0.0
  bloc_signals_flutter: ^1.0.0
  bloc_signals_riverpod: ^1.0.0
```

### Option A: Expose a `BlocSignal` / `CubitSignal` to Existing Riverpod Widgets

Want to write a new feature or state controller with `BlocSignal`, but keep your existing Riverpod UI layer (`ConsumerWidget`, `WidgetRef`)? 

Simply call `.toProvider()`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';

// Create your new BlocSignal or CubitSignal
final todosCubit = TodosCubit();

// Convert it directly into a Riverpod NotifierProvider!
final todosProvider = todosCubit.toProvider();

// Now consume it anywhere in existing Riverpod widgets:
class LegacyRiverpodWidget extends ConsumerWidget {
  const LegacyRiverpodWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds reactively whenever todosCubit emits!
    final todos = ref.watch(todosProvider);

    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, i) => Text(todos[i].description),
    );
  }
}
```

### Option B: Adapt an Existing Riverpod Provider into `BlocSignal`

Have a legacy Riverpod provider that you need to read from a new `BlocSignalBuilder` widget?

Use `.toBlocSignal(ref)`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';

class NewFeatureWidget extends ConsumerWidget {
  const NewFeatureWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Adapt any Riverpod ProviderListenable into a BlocSignal container!
    // Automatically binds ref.onDispose to close the container when disposed.
    final todosBloc = legacyRiverpodProvider.toBlocSignal(ref);

    return BlocSignalBuilder<BlocSignalBase<List<Todo>>, List<Todo>>(
      bloc: todosBloc,
      builder: (context, todos) {
        return ListView.builder(
          itemCount: todos.length,
          itemBuilder: (context, i) => Text(todos[i].description),
        );
      },
    );
  }
}
```

### Converting `AsyncValue` <-> `AsyncState`

`bloc_signals_riverpod` also provides extension methods to map seamlessly between Riverpod's `AsyncValue` and Signals' `AsyncState`:

```dart
// Riverpod AsyncValue to Signals AsyncState
final asyncState = riverpodAsyncValue.toAsyncState();

// Signals AsyncState to Riverpod AsyncValue
final asyncValue = signalsAsyncState.toAsyncValue();
```

---

## Explore the Official Riverpod Ports on blocsignal.dev

To prove the DX gains and side-by-side equivalence, we've ported canonical state management examples directly from the official [`rrousselGit/riverpod`](https://github.com/rrousselGit/riverpod/tree/master/examples) monorepo into the `BlocSignal` open-source repository:

1. 📝 **Riverpod Todos** ([`examples/riverpod_todos`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/riverpod_todos)):
   - Replaces `@riverpod` codegen and `Notifier` with `CubitSignal<List<Todo>>` and synchronous `computed()` signals for reactive filter tabs and stats.
2. 🔍 **Pub.dev Package Search** ([`examples/riverpod_pub`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/riverpod_pub)):
   - Replaces Riverpod `AsyncNotifier` with `BlocSignal` and a streamless `restartable()` event transformer that automatically cancels in-flight API requests on keypresses without Rx streams.
3. 🦸 **Marvel Character Browser** ([`examples/riverpod_marvel`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/riverpod_marvel)):
   - Demonstrates API pagination, character search, and widget tree scoping via `BlocSignalProvider.value`.

Explore all **20 side-by-side benchmark ports** across BLoC, Signals, and Riverpod live at **[blocsignal.dev/#ported-examples](https://blocsignal.dev/#ported-examples)**!

---

## Built-In AI Agent Skills for Automated Migration

If you use AI coding assistants like **Antigravity**, **Gemini**, **Cursor**, or **GitHub Copilot**, `BlocSignal` publishes a dedicated Agent Plugin skill bundle (`riverpod_migration.md`). 

When your AI assistant inspects a project with `BlocSignal` skills enabled, it automatically understands:
* How to map `StateNotifierProvider` / `NotifierProvider` to `CubitSignal`;
* How to preserve auto-disposal and cancellation contracts;
* How to refactor `ConsumerWidget` rebuild boundaries to `BlocSignalBuilder` or `SignalBuilder`;
* How to apply `bloc_signals_riverpod` interop adapters during multi-phase refactoring.

---

## Summary

You don't need to throw away your existing architecture to enjoy the speed, simplicity, and zero-codegen elegance of reactive signals. 

With **`bloc_signals_riverpod`**, you can trial `BlocSignal` on a single screen today, bridge your existing Riverpod providers seamlessly, and upgrade your developer experience at your own pace.

* 🌐 **Website & Comparison Benchmarks**: [blocsignal.dev](https://blocsignal.dev)
* 📦 **Pub.dev Packages**: [`bloc_signals`](https://pub.dev/packages/bloc_signals) | [`bloc_signals_flutter`](https://pub.dev/packages/bloc_signals_flutter) | [`bloc_signals_riverpod`](https://pub.dev/packages/bloc_signals_riverpod)
* 🐙 **GitHub Repository**: [RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)
