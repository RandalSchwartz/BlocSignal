# Flutter bindings and ownership

This reference matches `bloc_signals_flutter` 1.2.x. Inspect the installed package when the version
differs.

## Provider ownership

Use the constructor that matches ownership:

| Form | Creates the bloc | Closes the bloc on dispose |
| --- | ---: | ---: |
| `BlocSignalProvider(create: ..., lazy: true)` | On first lookup | Yes, if created |
| `BlocSignalProvider(create: ..., lazy: false)` | During provider initialization | Yes |
| `BlocSignalProvider.value(value: ...)` | No | No |

```dart
BlocSignalProvider<CounterBloc>(
  create: (_) => CounterBloc(),
  lazy: false,
  child: const CounterPage(),
)
```

`lazy` defaults to `true`. Use `lazy: false` only when creation must happen before the first lookup.
The provider intentionally does not await the owned bloc's `close()` future during widget disposal.

Use `.value` only when another owner already controls the bloc's lifetime. Closing that bloc from
both the provider and its original owner is an ownership bug even though the current `close` method
is idempotent.

## State rebuilds

`BlocSignalBuilder` reads a supplied bloc or finds one from the nearest matching provider. Its
internal `SignalBuilder` watches `bloc.state`:

```dart
BlocSignalBuilder<CounterBloc, int>(
  builder: (context, count) => Text('$count'),
)
```

Pass `bloc:` when the instance is not provided in the current subtree.

The provider and state widgets accept `BlocSignalBase`, so they work with `BlocSignal` and
`CubitSignal`. `BlocSignalBuilder` depends on the provider when `bloc:` is omitted and switches to
a replacement instance.

`context.read<T>()` finds a provider without adding an inherited-widget dependency. Use it for
commands:

```dart
context.read<CounterBloc>().add(Increment());
```

`context.watch<T>()` depends on the provider and rebuilds if the provided bloc instance changes.
It does not subscribe to `bloc.state`. Do not replace a state-aware `BlocBuilder` with
`context.watch<T>().stateValue`; use `BlocSignalBuilder` or a signals widget.

Use `context.select<B, R>` inside `build` for a narrow state slice:

```dart
final isSubmitEnabled = context.select<FormCubit, bool>(
  (cubit) => cubit.stateValue.canSubmit,
);
```

> [!TIP]
> **Generic Type Signature & Selector Parameter (`context.select<B, R>`)**:
> In `bloc_signals_flutter`, `context.select` takes **2** generic type parameters:
> 1. `B`: The `BlocSignalBase` container type (for example `FormCubit` or `CounterBloc`).
> 2. `R`: The selected return value type (for example `bool` or `String`).
>
> Unlike `flutter_riverpod` (which uses 3 generic parameters in some forms) or classic `flutter_bloc` context selection, `bloc_signals_flutter` passes the **`bloc` container instance** to the selector callback (`(bloc) => bloc.stateValue.canSubmit`), allowing direct property access via `bloc.stateValue`.

It rebuilds the element when the selected value changes by `!=`. Keep each element's select calls
unconditional and in a stable order because subscriptions are cached by call index. The provider
lookup registers an inherited dependency (`listen: true`), so if an ancestor provider swaps its
container instance, `context.select` automatically rebinds to the new container and continues
observing state updates seamlessly.

## Listeners, consumers, and selectors

`BlocSignalListener<T, S>` captures the current state on subscription, suppresses the effect's
initial run, and invokes its listener for later unequal states. Use `listenWhen` to filter with the
previous and current state:

```dart
BlocSignalListener<AuthBloc, AuthState>(
  listenWhen: (previous, current) => previous != current,
  listener: (context, state) {
    if (state case Authenticated()) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  },
  child: const LoginForm(),
)
```

The listener callback receives only the current state; `listenWhen` receives both values. An
unrelated parent rebuild does not restart the effect. When `bloc:` is omitted, the listener
uses a non-listening provider lookup, so a provider instance swap can be missed until another
widget update runs. Pass the bloc explicitly or verify replacement behavior in a widget test when
the provider can change.

`BlocSignalBuilder` supports `buildWhen(previous, current)` to conditionally suppress rebuilds when state changes:

```dart
BlocSignalBuilder<CounterBloc, int>(
  buildWhen: (previous, current) => current.isEven,
  builder: (context, count) => Text('$count'),
)
```

`BlocSignalConsumer<T, S>` combines that listener with `BlocSignalBuilder`. It forwards both `listenWhen` and `buildWhen`. Its provider lookup does listen for instance replacement.


`BlocSignalSelector<T, S, V>` computes `V` from each source state and rebuilds only when the new
selection is unequal to the previous selection:

```dart
BlocSignalSelector<ProfileCubit, ProfileState, String>(
  selector: (state) => state.displayName,
  builder: (context, name) => Text(name),
)
```

Give the selected type meaningful equality and avoid mutating a selected object in place. The
selector is reinitialized when its bloc or selector callback changes. It cleans up its
effect and rebinds automatically when its bloc instance or selector changes.

`MultiBlocSignalListener` nests several listeners around one child. Individual listeners do not require a placeholder `child` parameter:

```dart
MultiBlocSignalListener(
  listeners: [
    BlocSignalListener<AuthBloc, AuthState>(
      listener: onAuthState,
    ),
    BlocSignalListener<SyncCubit, SyncState>(
      listener: onSyncState,
    ),
  ],
  child: const AppShell(),
)
```

### One-shot presentation side effects

For transient UI actions (dialogs, snackbars, navigation) that should not pollute domain state, prefer:
1. **Direct async UI handlers**: `await cubit.action(); if (context.mounted) ...` in the widget `onPressed` callback. Because `BlocSignal` updates synchronously, state is settled immediately upon return.
2. **`BlocSignalPresentationMixin` & `BlocSignalPresentationListener`**: A lightweight zero-dependency mixin pattern for 100% `bloc_presentation` API compatibility (see [migration.md](migration.md#migrating-from-bloc_presentation-to-blocsignal-one-shot-ui-side-effects)).


## Multiple providers

`MultiBlocSignalProvider` nests its providers in list order. Individual providers do not require a placeholder `child` parameter:

```dart
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(
      create: (_) => AuthBloc(),
    ),
    BlocSignalProvider<ThemeBloc>(
      create: (_) => ThemeBloc(),
    ),
  ],
  child: const AppShell(),
)
```

## Derived state and side effects

Create derived signals under an owner that outlives a build call. Valid owners include the bloc, a
`State` object, or a hooks API whose installed version owns disposal.

- Never call `effect` or `computed` from `build`.
- Dispose manual effects and subscriptions from `State.dispose`.
- Close a locally created bloc from the same owner.
- Do not assume optional `signals_hooks` APIs from an example. Inspect the version in the consumer
  project before using a hook.

For UI reactions, use `BlocSignalListener` when suppressing the initial state and filtering through
`listenWhen` match the feature. Preserve mounted checks around work that crosses an async gap. Use
a state-owned or widget-owned reaction when the listener must receive both previous and current
values.

> [!TIP]
> **Lint Rules for Flutter UI**:
> `bloc_signals_lint` enforces clean Flutter UI patterns with dedicated analyzer rules:
> - `avoid_emit_in_build`: Prohibits direct `emit()` / `add()` in `build()` while allowing them in event callback closures (for example `onPressed: () => ...`).
> - `avoid_context_watch_for_bloc_state`: Flags `context.watch<T>()` in `build()` and suggests `context.read<T>()` with `BlocSignalBuilder` or `context.select`.
> - `avoid_unused_select_result`: Flags discarded `context.select` invocations.

## Flutter Hooks Integration (Zero-Cost with `signals_hooks`)

Because `bloc.state` is natively a `ReadonlySignal<S>`, developers migrating from or using `flutter_hooks` do **not** need a separate glue-code package (like the legacy `flutter_hooks_bloc`). Using `package:signals_hooks`, any `HookWidget` can consume, filter, or react to `BlocSignal` state out-of-the-box:

```dart
class CounterHookView extends HookWidget {
  const CounterHookView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Create or read the bloc instance
    final bloc = useMemoized(() => CounterBloc());

    // 2. Direct reactive subscription without BlocBuilder / Consumer
    final count = useSignalValue(bloc.state);

    // 3. Inline reactive side-effects without BlocListener
    useSignalEffect(() {
      if (count > 10) debugPrint('Counter reached double digits: $count');
    });

    // 4. Fine-grained inline computed selections without BlocSelector
    final isEven = useComputed(() => count.isEven);

    return Scaffold(
      body: Text('Count: $count (Even: ${isEven.value})'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => bloc.add(Increment()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Key advantages for hook workflows:
- **No `flutter_hooks_bloc` Glue Code**: No need for `useBloc` or custom macro-widgets.
- **Zero-Cost Lifecycle Teardown**: Hooks naturally manage subscription lifecycle and unmount disposal.
- **Composable State**: Effortlessly combine BLoC signals with local widget signals using `useComputed` or `useSignalEffect`.

## Form Input Synchronization (`TextFormField` with `ValueKey`)

When synchronizing form fields (`TextFormField`) with `BlocSignalBuilder` or signal state, avoid mutating a `TextEditingController.text` property inside a `build` method or `useEffect` hook:

```dart
// ❌ BAD: Mutating controller during build triggers Flutter assertion:
// "setState() or markNeedsBuild() called during build."
useEffect(() {
  controller.text = displayValue;
  return null;
}, [displayValue]);
```

### Idiomatic `ValueKey` Pattern

The cleanest pattern in `bloc_signals_flutter` is using `initialValue` paired with a state-derived `ValueKey` on `TextFormField` inside `BlocSignalBuilder`:

```dart
BlocSignalBuilder<UserDataCubit, UserData>(
  builder: (context, userData) {
    final displayWeight = userData.displayWeight;

    return TextFormField(
      // Pair ValueKey with initialValue to re-initialize field on external state changes
      key: ValueKey('weight_${userData.unit}_$displayWeight'),
      initialValue: displayWeight.toStringAsFixed(1),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          context.read<UserDataCubit>().setWeight(parsed);
        }
      },
    );
  },
);
```

**Why this works**:
- **Zero Build-Phase Mutations**: Eliminates `controller.text` mutations during frame builds.
- **Automatic Sync on External Changes**: Updating `ValueKey` forces `TextFormField` to re-initialize cleanly with `initialValue` when state changes externally (such as state hydration or unit switching).
- **Clean Field State**: Allows standard typing and validation while keeping state reactivity declarative.

## Declarative Routing & Route Guards (Kaisel / GoRouter)

`bloc_signals_flutter` provides `extension BlocSignalValueListenableX<T> on BlocSignalBase<T>` which exposes `bloc.toValueListenable()`. This bridges synchronous signal emissions into Flutter's `ValueListenable` ecosystem, enabling declarative routers (such as Kaisel 1.1 or GoRouter) to re-evaluate route guards automatically on state transitions.

```dart
final router = KaiselRouterConfig(
  // 1. Compute initial route dynamically from current stateValue to prevent screen flash
  initial: authBloc.stateValue.isAuthenticated
      ? const HomeRoute()
      : const LoginRoute(),
  // 2. Wire reactive re-evaluation via toValueListenable()
  reevaluateOn: [authBloc.toValueListenable()],
  guards: [
    (proposed) {
      final isAuthenticated = authBloc.stateValue.isAuthenticated;

      // 3. Idempotent self-bypass: prevent infinite redirect loops
      if (!isAuthenticated && proposed.length == 1 && proposed.first is LoginRoute) {
        return proposed;
      }
      if (!isAuthenticated) {
        return const [LoginRoute()];
      }
      return proposed;
    },
  ],
);
```

For GoRouter:
```dart
final router = GoRouter(
  refreshListenable: authBloc.toValueListenable(),
  redirect: (context, state) {
    final loggedIn = authBloc.stateValue.isAuthenticated;
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn) return loggingIn ? null : '/login';
    if (loggingIn) return '/';
    return null;
  },
);
```

## Infinite scroll pagination recipes

When implementing infinite scroll pagination in Flutter with BlocSignal, follow these foundational architectural rules:
1. **Event-Boundary Concurrency**: Tag pagination fetch events with `transformer: droppable()` to drop duplicate scroll threshold flings synchronously on the same frame.
2. **Offset-Based Cursor**: Derive the start index directly from `stateValue.items.length` rather than storing an independent, mutable page counter that can desynchronize on network failures.
3. **Query Cancellation**: Tag search or filter mutation events with `transformer: restartable()` to automatically discard stale in-flight pagination requests when filters change.
4. **Zero Third-Party Widgets**: Use standard Flutter `ListView.builder` or `CustomScrollView` rather than proprietary pagination packages.

### Recipe 1: Standard Separation of Concerns (ScrollController + BLoC)

When keeping domain business logic pure and decoupled from the Flutter widget layer:

```dart
// 1. PostsBloc with streamless droppable() and restartable()
class PostsBloc extends BlocSignal<PostsEvent, PostsState> {
  PostsBloc({required PostRepository repository})
      : _repository = repository,
        super(initialState: const PostsState()) {
    on<PostsFetched>(_onPostsFetched, transformer: droppable());
    on<PostsSearchChanged>(_onSearchChanged, transformer: restartable());
  }

  final PostRepository _repository;

  Future<void> _onPostsFetched(
    PostsFetched event,
    void Function(PostsState) emit,
  ) async {
    if (stateValue.hasReachedMax) return;
    try {
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

  Future<void> _onSearchChanged(
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

// 2. Flutter View with ScrollController threshold trigger
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
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= (maxScroll * 0.9)) {
      context.read<PostsBloc>().add(const PostsFetched());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<PostsBloc, PostsState>(
      builder: (context, state) {
        if (state.status == PostsStatus.loading && state.posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
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
            return PostTile(post: state.posts[index]);
          },
        );
      },
    );
  }
}
```

### Recipe 2: The Self-Paging Controller (Zero Glue Code & 100% StatelessWidget)

To eliminate `StatefulWidget`, `initState`, and `dispose` boilerplate completely, mix `CubitSignalMixin` and `BlocSignalMixin` directly into `ScrollController`. The controller serves simultaneously as Flutter's `ScrollController` and the reactive `BlocSignalBase`:

```dart
class PaginatedPostsController extends ScrollController
    with CubitSignalMixin<PostsState>, BlocSignalMixin<PostsEvent, PostsState> {
  PaginatedPostsController({required PostRepository repository})
      : _repository = repository {
    initCubitSignal(initialState: const PostsState());

    on<PostsFetched>(_onPostsFetched, transformer: droppable());
    on<PostsSearchChanged>(_onSearchChanged, transformer: restartable());

    // Controller monitors its own viewport geometry
    addListener(_onScrollChanged);
  }

  final PostRepository _repository;

  void _onScrollChanged() {
    if (!hasClients) return;
    if (offset >= (position.maxScrollExtent * 0.9)) {
      add(const PostsFetched());
    }
  }

  Future<void> _onPostsFetched(
    PostsFetched event,
    void Function(PostsState) emit,
  ) async {
    if (stateValue.hasReachedMax) return;
    try {
      final posts = await _repository.fetchPosts(
        query: stateValue.searchQuery,
        startIndex: stateValue.posts.length,
      );
      emit(stateValue.copyWith(
        status: PostsStatus.success,
        posts: [...stateValue.posts, ...posts],
        hasReachedMax: posts.isEmpty,
      ));
    } catch (_) {
      emit(stateValue.copyWith(status: PostsStatus.failure));
    }
  }

  Future<void> _onSearchChanged(
    PostsSearchChanged event,
    void Function(PostsState) emit,
  ) async {
    // restartable query implementation...
  }

  @override
  void dispose() {
    removeListener(_onScrollChanged);
    close();
    super.dispose();
  }
}

// 100% StatelessWidget UI without initState or controller disposal boilerplate:
class PostsView extends StatelessWidget {
  const PostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PaginatedPostsController>();

    return BlocSignalBuilder<PaginatedPostsController, PostsState>(
      builder: (context, state) {
        return ListView.builder(
          controller: controller, // Direct ScrollController binding
          itemCount: state.posts.length + (state.hasReachedMax ? 0 : 1),
          itemBuilder: (context, index) {
            if (index >= state.posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return PostTile(post: state.posts[index]);
          },
        );
      },
    );
  }
}
```

## Missing-provider failures

`BlocSignalProvider.of<T>` throws `FlutterError` when no exact provider type is found. Check that the
lookup context is below the provider and that the generic type matches the provided concrete bloc.
Do not catch the error and construct a hidden fallback bloc.
