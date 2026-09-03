---
series: "BlocSignal Architecture & Practice"
title: "Taming Flutter Infinite Scroll: Why 3 Lines of async* Missed the Point, and How BlocSignal Fixes It"
description: "Explore why using async* generators for infinite scroll pagination in Flutter hides subtle concurrency crashes, and discover how BlocSignal solves rapid scrolling race conditions streamlessly with droppable()."
tags: flutter, dart, architecture, statemanagement
published: true
---

## The Ubiquitous Infinite Scroll Pagination Bug

Almost every Flutter engineer has encountered the dreaded infinite scroll race condition in production.

The user opens a list, flings their thumb down the screen on a spotty cellular connection, and triggers multiple scroll notifications past the bottom threshold within milliseconds. Before the first asynchronous HTTP network request finishes, the scroll listener fires again. 

Suddenly, your list duplicates items, page counters jump ahead, or the state machine locks up entirely.

Recently, mobile developer Ali Wajdan published a widely discussed article titled [3 Lines of Dart async* Code That Fixed My Infinite Scroll Pagination](https://aliwajdan.medium.com/3-lines-of-dart-async-code-that-fixed-my-infinite-scroll-pagination-0485d392f567). 

In his article, Ali accurately diagnoses the root cause of standard pagination headaches:
> *"Most Flutter pagination code I have seen, including my own for years, wraps a mutable state object around a scroll listener. A page counter, a loading boolean, a hasMore flag, and a fetch method the UI calls when it hits the scroll threshold. It works until two scroll events fire close together, or a rebuild triggers a second load before the first future resolves... It is a classic race condition, and it gets worse once the state lives across a page counter, a hasMore flag, and a loading flag that all need to stay in sync."*

To escape this trap, Ali suggested encapsulating pagination logic inside a Dart `async*` generator and consuming it with a `StreamIterator`:

```dart
// The pattern proposed in Ali Wajdan's article
Stream<List<Post>> fetchPostsPaginated(String query) async* {
  var page = 0;
  var hasMore = true;
  while (hasMore) {
    final batch = await api.fetchPosts(query, page: page);
    hasMore = batch.isNotEmpty;
    page++;
    yield batch;
  }
}

final iterator = StreamIterator(fetchPostsPaginated(query));

Future<List<Post>> loadNextPage() async {
  if (!await iterator.moveNext()) return const [];

  return iterator.current;
}
```

On the surface, moving mutable state into local generator variables looks clean. But does it actually solve the concurrency problem in production?

Let us take a closer look.

---

## 🔍 Why `async*` and `StreamIterator` Crack Under Pressure

While moving the `page` counter and `hasMore` flag inside the generator prevents outside tampering, the implementation suffers from severe architectural pitfalls:

### 1. The Hidden Concurrency Crash: `Bad state: Cannot call moveNext...`
Dart's `StreamIterator.moveNext()` is explicitly **not concurrency-safe**. 

If a fast scroll fling or a double-rebuild calls `loadNextPage()` while a previous `moveNext()` is still awaiting the network, Dart immediately throws an unhandled runtime error:
```plaintext
Bad state: Cannot call moveNext while a previous call to moveNext is still pending.
```
Because of this, the author admits in the article that he still had to maintain a manual guard:
> *"I still guard the UI trigger with the one Future that loadNextPage returns... That guard is the only piece of state I own now."*

In other words, you have not actually eliminated the concurrency guard—you have merely introduced a stream iterator abstraction on top of it.

### 2. Pulling Chunks vs. Reactive Unidirectional Data Flow
An iterator is an imperative pull-based consumer. It yields a raw batch of items, but a real-world Flutter UI needs a comprehensive reactive state model:
- What happens when a network error occurs on page 4?
- How does the UI render a bottom spinner indicator while retaining previously fetched items?
- How do we handle pull-to-refresh or empty states?

With an iterator, you still have to maintain an external state container to accumulate batches, catch errors, and update the UI.

### 3. Resource Leak Risks & Teardown Friction
A `StreamIterator` holds an active stream subscription. If the user navigates away from the screen, you must remember to explicitly invoke `await iterator.cancel()`. Furthermore, whenever a search query or filter changes, you must tear down the old iterator, instantiate a fresh generator, and re-bind the pipeline.

---

## ⚡ The Architectural Lesson: Concurrency Belongs at the Event Boundary

The core insight is simple: **concurrency control should never be buried inside an imperative data-pulling loop, nor should it leak into UI scroll listeners.**

Concurrency is an **event scheduling concern**. The moment a user's gesture or scroll threshold emits an event, the system should declare how overlapping executions are handled.

In **BlocSignal**, concurrency is a first-class citizen governed by **streamless event transformers**.

---

## 🛡️ The Idiomatic BlocSignal Solution: `droppable()`

In `bloc_signals`, preventing duplicate requests during infinite scroll requires exactly one parameter: **`transformer: droppable()`**.

Here is how a clean, production-ready `PostsBloc` looks:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';

sealed class PostsEvent {
  const PostsEvent();
}

final class PostsFetched extends PostsEvent {
  const PostsFetched();
}

final class PostsSearchChanged extends PostsEvent {
  const PostsSearchChanged(this.query);
  final String query;
}

enum PostsStatus { initial, loading, success, failure }

@immutable
class PostsState {
  const PostsState({
    this.status = PostsStatus.initial,
    this.posts = const [],
    this.hasReachedMax = false,
    this.searchQuery = '',
  });

  final PostsStatus status;
  final List<Post> posts;
  final bool hasReachedMax;
  final String searchQuery;

  PostsState copyWith({
    PostsStatus? status,
    List<Post>? posts,
    bool? hasReachedMax,
    String? searchQuery,
  }) {
    return PostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class PostsBloc extends BlocSignal<PostsEvent, PostsState> {
  PostsBloc({required PostRepository repository})
      : _repository = repository,
        super(initialState: const PostsState()) {
    
    // 1. Drop duplicate scroll triggers while a page fetch is in flight
    on<PostsFetched>(
      _onPostsFetched,
      transformer: droppable(),
    );

    // 2. Automatically cancel and restart when the search query changes
    on<PostsSearchChanged>(
      _onPostsSearchChanged,
      transformer: restartable(),
    );
  }

  final PostRepository _repository;

  Future<void> _onPostsFetched(
    PostsFetched event,
    void Function(PostsState) emit,
  ) async {
    if (stateValue.hasReachedMax) return;

    try {
      // Natural offset pagination: stateValue.posts.length IS your cursor!
      final newPosts = await _repository.fetchPosts(
        query: stateValue.searchQuery,
        startIndex: stateValue.posts.length,
        limit: 10,
      );

      emit(
        newPosts.isEmpty
            ? stateValue.copyWith(hasReachedMax: true)
            : stateValue.copyWith(
                status: PostsStatus.success,
                posts: [...stateValue.posts, ...newPosts],
                hasReachedMax: newPosts.length < 10,
              ),
      );
    } catch (_) {
      emit(stateValue.copyWith(status: PostsStatus.failure));
    }
  }

  Future<void> _onPostsSearchChanged(
    PostsSearchChanged event,
    void Function(PostsState) emit,
  ) async {
    emit(stateValue.copyWith(
      status: PostsStatus.loading,
      searchQuery: event.query,
    ));

    try {
      final posts = await _repository.fetchPosts(
        query: event.query,
        startIndex: 0,
        limit: 10,
      );

      emit(PostsState(
        status: PostsStatus.success,
        posts: posts,
        hasReachedMax: posts.length < 10,
        searchQuery: event.query,
      ));
    } catch (_) {
      emit(stateValue.copyWith(status: PostsStatus.failure));
    }
  }
}
```

---

## 🔬 Under the Hood: Why `droppable()` is Glitch-Free and Streamless

How does `droppable()` prevent race conditions without allocating Rx streams or microtask queues?

In classic `package:bloc_concurrency`, transformers convert an incoming event stream using Rx operators (such as `exhaustMap`). That introduces stream controllers, subscription pipelines, and asynchronous microtask dispatch delays.

In `BlocSignal`, event transformers are **streamless higher-order functions**:

```dart
EventTransformer<E, StateType> droppable<E, StateType>() {
  var isProcessing = false;
  return (event, handler, emit) async {
    if (isProcessing) return;
    isProcessing = true;
    try {
      final result = handler(event, emit);
      if (result is Future) {
        await result;
      }
    } finally {
      isProcessing = false;
    }
  };
}
```

Look at how elegant this is:
1. When the first `PostsFetched` event arrives, `isProcessing` flips to `true` **synchronously in the exact same call frame**.
2. If the user's scroll fling generates 8 additional scroll events in that same frame or while the HTTP request is pending, each incoming event hits `if (isProcessing) return;` and is safely, immediately discarded.
3. Once the HTTP request completes and state is emitted, `finally` resets `isProcessing = false`, allowing the next scroll boundary trigger to proceed.

Zero race conditions. Zero microtask lag. Zero Stream allocations.

---

## 🎯 Natural Cursor Pagination: Forgetting the `page` Counter

Notice another detail in `PostsBloc`: **there is no `page` counter variable anywhere.**

When you manage paginated lists, maintaining a separate `int page = 0` counter that increments alongside `posts.addAll(...)` is an anti-pattern. If an API request fails, or if duplicate events trigger, the counter can desynchronize from the actual item count.

Instead, derive your offset directly from the source of truth:
```dart
startIndex: stateValue.posts.length
```
The length of your accumulated list **is** your pagination cursor. There is nothing to desynchronize, nothing to increment prematurely, and nothing to reset manually.

---

## 🔄 Instant Search Reset with `restartable()`

What happens when the user types a new search query into the search bar while an infinite scroll request is actively in flight?

In Ali's generator example, resetting required manual teardown:
> *"Changing a search query or filter means creating a new generator, not carefully resetting three fields and hoping you got them all."*

In BlocSignal, you simply tag search events with `transformer: restartable()`:

```dart
on<PostsSearchChanged>(
  _onPostsSearchChanged,
  transformer: restartable(),
);
```

When a new search query arrives, `restartable()` increments an internal token. Any in-flight HTTP responses from older queries or prior scroll pages are automatically dropped from emitting state. The list smoothly switches to the new search query without race conditions or ghost responses.

---

## 📱 The Flutter UI: Declarative and Lightweight

Consuming this in Flutter is straightforward. We attach a `ScrollController` listener to dispatch `PostsFetched()` when the user is within 10% of the bottom, and build the UI using `BlocSignalBuilder`:

```dart
class PostsView extends StatefulWidget {
  const PostsView({super.key});

  @override
  State<PostsView> createState() => _PostsViewState();
}

class _PostsViewState extends State<PostsView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // Trigger when 90% scrolled
    if (currentScroll >= (maxScroll * 0.9)) {
      context.read<PostsBloc>().add(const PostsFetched());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite Scroll Posts'),
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
                context.read<PostsBloc>().add(PostsSearchChanged(query));
              },
            ),
          ),
        ),
      ),
      body: BlocSignalBuilder<PostsBloc, PostsState>(
        builder: (context, state) => switch (state.status) {
          PostsStatus.initial => const Center(
              child: CircularProgressIndicator(),
            ),
          PostsStatus.failure => const Center(
              child: Text('Failed to load posts.'),
            ),
          PostsStatus.loading && state.posts.isEmpty => const Center(
              child: CircularProgressIndicator(),
            ),
          PostsStatus.success || PostsStatus.loading => state.posts.isEmpty
              ? const Center(child: Text('No posts found.'))
              : ListView.builder(
                  controller: _scrollController,
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
                ),
        },
      ),
    );
  }
}
```

Because `BlocSignalBuilder` listens to fine-grained signal changes, UI updates execute synchronously in the exact frame state is emitted, completely avoiding frame-skipping and microtask latency.

---

## 📊 Architectural Comparison

| Architectural Metric | Ali's `async*` + `StreamIterator` | Manual Flags in Widget / State | `BlocSignal` with `droppable()` |
| :--- | :--- | :--- | :--- |
| **Concurrency Guard** | ❌ Throws `StateError` on concurrent `moveNext()` | ⚠️ Brittle `isLoading` flags prone to race conditions | ✅ 100% synchronous guard lock |
| **Cursor Management** | Scoped to generator | Mutable `page` counter | Natural offset (`posts.length`) |
| **Search Cancellation** | Requires manual generator recreation | Complex cancellation tokens | Built-in via `transformer: restartable()` |
| **UI Integration** | Pull-only chunk fetching | Cluttered widget code | Declarative, reactive UI via signals |
| **Lifecycle & Teardown** | Manual `iterator.cancel()` | Manual controller disposal | Automatic container cleanup via `close()` |
| **Runtime Overhead** | Stream iteration overhead | Minimal | Streamless pure Dart functions |

---

## Conclusion

Ali Wajdan's article highlights a genuine problem: manual state flags around scroll listeners are a frequent source of production bugs in Flutter.

However, attempting to solve event concurrency by turning asynchronous APIs into stream generators swaps one set of bugs for another.

By treating concurrency as an **event boundary policy** with `droppable()` and `restartable()`, you gain:
1. **Bulletproof concurrency** that gracefully ignores rapid thumb flings.
2. **Zero-drift pagination** powered by natural list offset indexing.
3. **Streamless performance** with 0ms signal propagation.

---

### Resources & Links

* 🔗 Original Article by Ali Wajdan: [3 Lines of Dart async* Code That Fixed My Infinite Scroll Pagination](https://aliwajdan.medium.com/3-lines-of-dart-async-code-that-fixed-my-infinite-scroll-pagination-0485d392f567)
* 📜 Interactive Concurrency Guide: [Event Concurrency Transformers on blocsignal.dev](https://blocsignal.dev/docs/event-transformers)
* 💻 Full Runnable Example & Test Suite: [examples/infinite_scroll on GitHub](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/infinite_scroll)
* 📦 [`bloc_signals` on pub.dev](https://pub.dev/packages/bloc_signals)
* 📦 [`bloc_signals_flutter` on pub.dev](https://pub.dev/packages/bloc_signals_flutter)
* 🌐 Official Documentation: [blocsignal.dev](https://blocsignal.dev)
* 🌟 GitHub Repository: [RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)
