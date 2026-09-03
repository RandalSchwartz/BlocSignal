---
series: "BlocSignal Architecture & Practice"
title: "Taming Flutter Infinite Scroll (Part 2): Turning ScrollController into a Reactive State Machine with CubitSignalMixin"
description: "Discover how to eliminate Flutter StatefulWidget boilerplate and overcome Dart's single-inheritance wall by combining ScrollController with CubitSignalMixin and BlocSignalMixin for a 100% StatelessWidget UI."
tags: flutter, dart, architecture, statemanagement
published: true
---

## The Infinite Scroll Rite of Passage

In [Part 1: Taming Flutter Infinite Scroll: Why 3 Lines of async* Missed the Point, and How BlocSignal Fixes It](https://dev.to/gde/taming-flutter-infinite-scroll-why-3-lines-of-async-missed-the-point-and-how-blocsignal-fixes-it-3n48), we explored why wrapping mutable state in `async*` generators and `StreamIterator` cracks under pressure when users rapidly fling a list. We demonstrated how `BlocSignal`’s streamless `droppable()` transformer solves thumb-flinging race conditions synchronously at the event boundary without Rx streams or microtask lag.

Yet, even after solving event concurrency with a pure BLoC, many Flutter developers are left with a nagging architectural itch.

Search pub.dev for `"infinite scroll"` or `"pagination"`, and you will find dozens of packages—`infinite_scroll_pagination`, `lazy_load_scrollview`, `flutter_pagewise`, `loadmore`. It is practically a rite of passage for every Flutter developer to install at least one of them.

Why do these packages exist in such numbers?

Because implementing pagination with standard Flutter controllers requires tedious widget-level plumbing:
- Creating a `StatefulWidget`.
- Instantiating and maintaining an instance of `ScrollController`.
- Subscribing to scroll metrics with `_scrollController.addListener(_onScroll)` in `initState`.
- Remembering to call `removeListener` and `_scrollController.dispose()` in `dispose()`.
- Manually calculating viewport extents (`offset >= maxScrollExtent * 0.9`).
- Gluing the scroll trigger to a state management call (`context.read<PostsBloc>().add(...)`).

Unfortunately, the third-party pagination packages on pub.dev often extract a heavy architectural tax:
1. **They hijack your widget tree**: They force you to replace standard Flutter widgets with proprietary wrappers like `PagedListView`, fighting your slivers, custom scroll physics, and layout styling.
2. **They invent competing controllers**: They introduce bespoke paging controllers alongside your existing BLoCs or Notifiers, creating two competing sources of truth that you must manually synchronize.
3. **They attempt to solve concurrency in the UI**: They try to debounce or guard fetch requests inside widget lifecycle callbacks instead of at the architectural event boundary.

What if you did not need a third-party pagination package at all? What if Flutter's standard `ScrollController` could **itself** be your reactive state container?

Let us examine why that was historically impossible in Dart—and how composable mixins change everything.

---

## 🧱 Dart's Single-Inheritance Wall

Why couldn't Flutter's `ScrollController` just extend `BlocSignal` or `CubitSignal`?

In Dart, a class can extend only **one** superclass.

Flutter's `ScrollController` extends `ChangeNotifier` (which implements `Listenable`). If you want a class to also be a `CubitSignal` or `BlocSignal`, Dart's single-inheritance constraint stops you dead in your tracks:

```dart
// ❌ Impossible in Dart (Multiple inheritance is forbidden):
class PaginatedPostsController extends ScrollController, BlocSignal<PostsEvent, PostsState> {
  // Dart analyzer error: Each class can have only one superclass.
}
```

Historically, this constraint forced developers into two unsatisfying compromises:

1. **The Proxy / Wrapper Anti-Pattern**: Creating a wrapper class that held an internal `_bloc` reference, requiring tedious method forwarding and lifecycle delegation.
2. **The Dual-Lifecycle Trap**: Managing a `ScrollController` and a `PostsBloc` as separate objects in the widget tree, gluing them together with `initState` listeners and cleaning both up in `dispose()`.

With **`CubitSignalMixin`** and **`BlocSignalMixin`** in `bloc_signals`, that single-inheritance wall is demolished.

---

## 🧬 How Composable Mixins Break the Wall

Because `BlocSignal` has a minimal, highly disciplined API contract, mixing it into arbitrary classes introduces zero namespace collisions:

```plaintext
┌────────────────────────────────────────────────────────────────────────┐
│                        BlocSignal Mixin Architecture                   │
├────────────────────────────────┬───────────────────────────────────────┤
│ Mixin                          │ Capabilities Added                    │
├────────────────────────────────┼───────────────────────────────────────┤
│ CubitSignalMixin<StateType>    │ state, stateValue, emit(newState),    │
│                                │ equals(), createEffect(), close()     │
├────────────────────────────────┼───────────────────────────────────────┤
│ BlocSignalMixin<Event, State>  │ on<E>(), concurrency transformers     │
│                                │ (droppable, restartable), add(event)  │
└────────────────────────────────┴───────────────────────────────────────┘
```

When a class adopts `CubitSignalMixin<StateType>`, it implements `BlocSignalBase<StateType>`. It gains:
- 0ms synchronous reactive signals (`state`).
- Direct synchronous state value access (`stateValue`).
- Automatic de-duplication (`emit(newState)` drops transitions when `newState == currentState`).
- Reactive observer tracking and lifecycle management.

And when combined with `BlocSignalMixin<Event, StateType>`, it gains full event-driven execution with streamless transformers like `droppable()` and `restartable()`.

This unlocks two clean architectural patterns for infinite scroll.

---

## 📐 Pattern A: The Reactive `PagingScrollController` (Separation of Concerns)

If your architectural philosophy demands that your domain business logic remain 100% pure Dart (with zero imports of `package:flutter/widgets.dart`), you can turn `ScrollController` into a focused, reactive boolean signal:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';

/// A ScrollController that is also a CubitSignal emitting whether 
/// the scroll viewport is within [threshold] pixels of the bottom.
class PagingScrollController extends ScrollController 
    with CubitSignalMixin<bool> {
  PagingScrollController({this.threshold = 200.0}) {
    // 1. Initialize the CubitSignalMixin with initial state
    initCubitSignal(initialState: false);

    // 2. Listen to scroll metrics internally
    addListener(_onScrollChanged);
  }

  /// Remaining scroll extent threshold in logical pixels (default: 200.0).
  final double threshold;
  bool _isControllerDisposed = false;

  void _onScrollChanged() {
    if (!hasClients) return;
    // position.extentAfter returns the exact remaining pixels after the viewport!
    final isNearBottom = position.extentAfter <= threshold;

    // 3. emit() automatically de-duplicates:
    // Only triggers subscribers when the boolean flips between false and true!
    emit(isNearBottom);
  }

  @override
  void dispose() {
    if (_isControllerDisposed) return;
    _isControllerDisposed = true;
    removeListener(_onScrollChanged);
    close();
    super.dispose();
  }

  @override
  Future<void> close() async {
    if (!_isControllerDisposed) {
      _isControllerDisposed = true;
      removeListener(_onScrollChanged);
      super.dispose();
    }
    await super.close();
  }
}
```

### 💡 The `extentAfter` Secret: Why Pixels Beat Percentages

Notice line 20:
```dart
final isNearBottom = position.extentAfter <= threshold;
```

Most Flutter pagination tutorials write something like:
```dart
// ⚠️ The percentage trap:
final isBottom = offset >= maxScrollExtent * 0.9;
```

Calculating a percentage (such as `0.9`) creates an erratic user experience:
- On a **short list** of 1,000 pixels, 90% triggers when you are 100 pixels from the bottom.
- On a **long list** of 50,000 pixels, 90% triggers when you are **5,000 pixels** from the bottom—downloading pages far in advance that the user may never scroll to!

Flutter's `ScrollPosition.extentAfter` returns the **exact quantity of content in logical pixels remaining after the viewport's trailing edge** (`math.max(maxScrollExtent - pixels, 0.0)`).

Using `position.extentAfter <= 200.0`:
1. **Provides a consistent lead time**: You always start fetching the next page when the user is ~2 items away from the bottom, regardless of whether the list has 10 items or 10,000 items.
2. **Eliminates calculation boilerplate**: No multiplying `maxScrollExtent * 0.9`, no reading `offset`, and no bounds-checking when a list is empty. It is a single, clean comparison.

### The Superpower of Automatic De-duplication

Notice line 27: `emit(isNearBottom);`.

As a user scrolls vigorously near the bottom, scroll notifications fire dozens of times across 91%, 93%, 97%, and 99% of the viewport. In naive Flutter code, this requires manual boolean guards to prevent triggering duplicate actions.

With `CubitSignalMixin`, **de-duplication is automatic**. Because `emit()` checks `newState == currentState`, calling `emit(true)` twenty times in a row produces **zero** spurious signal updates. The signal fires exactly once when crossing the threshold downward, and exactly once when scrolling back upward!

Connecting this to your domain `PostsBloc` requires just a single declarative effect:

```dart
pagingController.createEffect(() {
  if (pagingController.stateValue) {
    postsBloc.add(const PostsFetched());
  }
});
```

The domain BLoC remains completely independent of Flutter, while the widget avoids doing manual scroll extent arithmetic.

---

## ⚡ Pattern B: The Self-Paging Domain Controller (Zero-Bridge Architecture)

Now, let us take the architectural leap.

What if you do not want a separate controller, a separate BLoC, and glue code between them? What if your controller **is** the `ScrollController`, and your controller **is** the `BlocSignal`?

Here is `PaginatedPostsController`:

```dart
import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/widgets.dart';
import '../models/post.dart';

class PaginatedPostsController extends ScrollController
    with
        CubitSignalMixin<PostsState>,
        BlocSignalMixin<PostsEvent, PostsState> {
  PaginatedPostsController({
    this.threshold = 200.0,
    required PostRepository repository,
  }) : _repository = repository {
    // 1. Initialize CubitSignal state
    initCubitSignal(initialState: const PostsState());

    // 2. Streamless concurrency: drop overlapping scroll triggers
    on<PostsFetched>(
      _onPostsFetched,
      transformer: droppable(),
    );

    // 3. Streamless concurrency: cancel and restart on search query change
    on<PostsSearchChanged>(
      _onPostsSearchChanged,
      transformer: restartable(),
    );

    // 4. Controller listens to its own scroll geometry!
    addListener(_onScrollChanged);
  }

  /// Remaining scroll extent threshold in logical pixels (default: 200.0).
  final double threshold;
  final PostRepository _repository;
  bool _isControllerDisposed = false;

  void _onScrollChanged() {
    if (!hasClients) return;
    // Single, clean extentAfter check:
    if (position.extentAfter <= threshold) {
      add(const PostsFetched());
    }
  }

  Future<void> _onPostsFetched(
    PostsFetched event,
    void Function(PostsState) emit,
  ) async {
    if (stateValue.hasReachedMax) return;

    try {
      if (stateValue.status == PostsStatus.initial) {
        final posts = await _repository.fetchPosts(
          startIndex: 0,
          count: 10,
          query: stateValue.searchQuery,
        );
        return emit(stateValue.copyWith(
          status: PostsStatus.success,
          posts: posts,
          hasReachedMax: false,
        ));
      }

      final posts = await _repository.fetchPosts(
        startIndex: stateValue.posts.length,
        count: 10,
        query: stateValue.searchQuery,
      );

      emit(posts.isEmpty
          ? stateValue.copyWith(hasReachedMax: true)
          : stateValue.copyWith(
              status: PostsStatus.success,
              posts: [...stateValue.posts, ...posts],
              hasReachedMax: stateValue.posts.length + posts.length >= 30,
            ));
    } catch (_) {
      emit(stateValue.copyWith(status: PostsStatus.failure));
    }
  }

  Future<void> _onPostsSearchChanged(
    PostsSearchChanged event,
    void Function(PostsState) emit,
  ) async {
    final posts = await _repository.fetchPosts(
      startIndex: 0,
      count: 10,
      query: event.query,
    );
    emit(stateValue.copyWith(
      status: PostsStatus.success,
      posts: posts,
      hasReachedMax: false,
      searchQuery: event.query,
    ));
  }

  @override
  void dispose() {
    if (_isControllerDisposed) return;
    _isControllerDisposed = true;
    removeListener(_onScrollChanged);
    close();
    super.dispose();
  }

  @override
  Future<void> close() async {
    if (!_isControllerDisposed) {
      _isControllerDisposed = true;
      removeListener(_onScrollChanged);
      super.dispose();
    }
    await super.close();
  }
}
```

Look at what this class accomplishes:
1. **It is a `ScrollController`**: You can pass it directly to `ListView.builder(controller: controller)`.
2. **It is a `BlocSignalBase`**: You can pass it directly to `BlocSignalBuilder` or provide it with `BlocSignalProvider`.
3. **It manages its own event dispatch**: It inspects its own scroll offset and calls `add(const PostsFetched())`.
4. **It governs its own concurrency**: `transformer: droppable()` guarantees that rapid thumb flings while a network request is in-flight are synchronously ignored on the same frame.

---

## 🎨 The Flutter UI: A 100% `StatelessWidget`

Now observe what happens to the Flutter UI layer:

```dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../controllers/paginated_posts_controller.dart';

class SelfPagingPostsView extends StatelessWidget {
  const SelfPagingPostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PaginatedPostsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Paging Controller (Stateless)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                controller.add(PostsSearchChanged(query));
              },
            ),
          ),
        ),
      ),
      body: BlocSignalBuilder<PaginatedPostsController, PostsState>(
        builder: (context, state) {
          switch (state.status) {
            case PostsStatus.initial:
              return const Center(child: CircularProgressIndicator());

            case PostsStatus.failure:
              return const Center(child: Text('Failed to load posts'));

            case PostsStatus.success:
              if (state.posts.isEmpty) {
                return const Center(child: Text('No posts found.'));
              }
              return ListView.builder(
                controller: controller, // Plugs directly into Flutter's native ListView!
                itemCount: state.hasReachedMax
                    ? state.posts.length
                    : state.posts.length + 1,
                itemBuilder: (context, index) {
                  if (index >= state.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = state.posts[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${post.id}')),
                    title: Text(post.title),
                    subtitle: Text(post.body),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
```

Notice what is **completely absent** from this widget:
- ❌ No `StatefulWidget`
- ❌ No `State.initState`
- ❌ No `State.dispose`
- ❌ No `ScrollController` listener wiring
- ❌ No manual scroll threshold math
- ❌ No third-party pagination widgets

The widget is a pure, declarative, 100% `StatelessWidget`. It renders the state when signals emit, and it routes user interactions directly to the controller.

---

## 🛡️ Safe Lifecycle & Teardown Architecture

One important detail when unifying a Flutter `ChangeNotifier` and a `BlocSignalBase` is lifecycle coordination.

When providing `PaginatedPostsController` through `BlocSignalProvider`:

```dart
BlocSignalProvider<PaginatedPostsController>(
  lazy: false,
  create: (context) => PaginatedPostsController(repository: repository)
    ..add(const PostsFetched()),
  child: const MaterialApp(home: SelfPagingPostsView()),
)
```

`BlocSignalProvider` automatically invokes `bloc.close()` when the provider is unmounted. 

Furthermore, passing `controller: controller` to `ListView.builder` does **not** cause the `ListView` to dispose the controller; in Flutter, widgets only dispose controllers that they instantiated internally.

To ensure safe, leak-free teardown regardless of how the controller is managed, we implement an idempotent teardown guard:

```dart
bool _isControllerDisposed = false;

@override
void dispose() {
  if (_isControllerDisposed) return;
  _isControllerDisposed = true;
  removeListener(_onScrollChanged);
  close();
  super.dispose();
}

@override
Future<void> close() async {
  if (!_isControllerDisposed) {
    _isControllerDisposed = true;
    removeListener(_onScrollChanged);
    super.dispose();
  }
  await super.close();
}
```

Whether teardown is triggered via Flutter's `dispose()` or `BlocSignalProvider`'s `close()`, listeners are removed, signals are cleaned up, and neither `super.dispose()` nor `super.close()` is ever executed more than once.

---

## 📊 Comprehensive Architectural Comparison

| Dimension | Third-Party Packages (for example `infinite_scroll_pagination`) | Classic Straight BLoC (`examples/infinite_scroll`) | Pattern A: Reactive `PagingScrollController` | Pattern B: Self-Paging Mixin (`examples/infinite_scroll_mixin`) |
| :--- | :--- | :--- | :--- | :--- |
| **Widget Tree Impact** | ❌ Proprietary wrappers (`PagedListView`) | ✅ 100% Standard Flutter widgets | ✅ 100% Standard Flutter widgets | ✅ 100% Standard Flutter widgets |
| **UI Widget Structure** | `StatefulWidget` or wrapper | `StatefulWidget` (`initState`/`dispose`) | `StatefulWidget` or effect | ✅ **100% `StatelessWidget`** |
| **Source of Truth** | ❌ Competing controllers fighting BLoC | ✅ Single BLoC container | ✅ Single BLoC container | ✅ Single unified controller |
| **Concurrency Guard** | Brittle UI-level guards | ✅ Synchronous `droppable()` | ✅ Synchronous `droppable()` | ✅ Synchronous `droppable()` |
| **Domain Layer Separation** | Coupled to package | ✅ 100% Pure Dart domain | ✅ 100% Pure Dart domain | Blended UI controller & state machine |
| **External Dependencies** | Heavy third-party package | None (pure `bloc_signals`) | None (pure `bloc_signals`) | None (pure `bloc_signals`) |

---

## 🎯 Which Strategy Should You Choose?

Both patterns are first-class citizens in the `BlocSignal` repository:

1. **Use the Classic Straight BLoC Strategy ([`examples/infinite_scroll`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/infinite_scroll))** when:
   - Your team adheres to strict Clean Architecture where domain BLoCs must never import Flutter packages.
   - The same BLoC is shared across CLI tools, Jaspr web applications, or server-side Dart services.
   - You prefer traditional `StatefulWidget` controller lifecycles in the UI layer.

2. **Use the Self-Paging Mixin Strategy ([`examples/infinite_scroll_mixin`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/infinite_scroll_mixin))** when:
   - You want maximum developer velocity and minimal boilerplate.
   - You want your UI views to be 100% `StatelessWidget` with zero glue code.
   - You want a self-contained controller that manages both the scroll mechanics and the paginated state machine in one cohesive class.

---

## Conclusion

Infinite scroll does not have to be a rite of passage filled with race condition bugs, competing controllers, or proprietary widget wrappers.

By combining `droppable()` concurrency with `CubitSignalMixin` and `BlocSignalMixin`:
- You overcome Dart's single-inheritance constraint.
- You eliminate duplicate scroll notifications automatically.
- You write 100% `StatelessWidget` UI screens without a single line of `initState` or `dispose` boilerplate.

---

### Resources & Companion Code

* 🔗 Part 1 of this series: [Taming Flutter Infinite Scroll: Why 3 Lines of async* Missed the Point, and How BlocSignal Fixes It](https://dev.to/gde/taming-flutter-infinite-scroll-why-3-lines-of-async-missed-the-point-and-how-blocsignal-fixes-it-3n48)
* 💻 Classic Strategy Example: [examples/infinite_scroll on GitHub](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/infinite_scroll)
* 💻 Self-Paging Mixin Strategy Example: [examples/infinite_scroll_mixin on GitHub](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/infinite_scroll_mixin)
* 📜 Composable Mixins Guide: [CubitSignalMixin & BlocSignalMixin Documentation](https://blocsignal.dev/docs/composable-mixins)
* 📦 [`bloc_signals` on pub.dev](https://pub.dev/packages/bloc_signals)
* 📦 [`bloc_signals_flutter` on pub.dev](https://pub.dev/packages/bloc_signals_flutter)
* 🌐 Official Documentation Hub: [blocsignal.dev](https://blocsignal.dev)
* 🌟 GitHub Repository: [RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)

