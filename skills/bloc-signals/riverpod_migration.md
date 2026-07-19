# Migration Guide: From Riverpod to BlocSignal

This guide explains how to migrate your Flutter and Dart applications from Riverpod (`package:flutter_riverpod` and `@riverpod` annotations) to `BlocSignal` (`package:bloc_signals` and `package:bloc_signals_flutter`) coupled with the `signals` primitives.

---

## 1. Paradigm Shift: Global Scopes vs. Inherited Widget Tree

Riverpod is built around a global state paradigm where providers are declared as global/static variables and resolved using a `WidgetRef` (usually provided by a `ConsumerWidget` or `Consumer`). 

`BlocSignal` and `bloc_signals_flutter` use classic Flutter `InheritedWidget` dependency injection (`BlocSignalProvider`), aligning closely with standard Flutter scoping and widget tree lifecycles.

### Concept Mapping

| Riverpod (v2/v3) | BlocSignal / Signals Equivalent | Details |
| :--- | :--- | :--- |
| `Notifier<State>` | `BlocSignal<void, State>` | Cubit-style direct methods modifying state. |
| `AsyncNotifier<State>` | `BlocSignal<Event, State>` | Business logic handling asynchronous state transitions via event mappings or async Cubit methods. |
| `Provider<T>` | `ReadOnlySignal<T>` | Computed signals for derived states. |
| `StateProvider<T>` | `Signal<T>` | Standard mutable signal primitives. |
| `ConsumerWidget` / `Consumer` | `BlocSignalBuilder` or `Watch` | Listening/rebuilding on signal changes. |
| `ref.watch(provider)` | `context.watch<Bloc>()` / `signal.value` | Subscribing to state/signal updates. |
| `ref.read(provider)` | `context.read<Bloc>()` / `signal.peek()` | Accessing values without creating rebuild dependencies. |

---

## 2. Key Gotchas & How to Solve Them

### Gotcha 1: Replacing Riverpod `.family` with `SignalContainer`
In Riverpod, you can pass arguments to providers using the `.family` modifier (e.g. `userProvider(userId)`). This caches and retrieves provider instances based on the argument.

With `signals`, you can replace the `.family` pattern cleanly using **`SignalContainer`** with caching enabled.

#### Before (Riverpod family)
```dart
final userProvider = FutureProvider.family<User, String>((ref, userId) async {
  return fetchUser(userId);
});

// Consumption:
final user = ref.watch(userProvider('user_123'));
```

#### After (Signals with SignalContainer)
```dart
final userContainer = signalContainer<AsyncSignal<User>, String>(
  (userId) => futureSignal(() => fetchUser(userId)),
  cache: true,
);

// Consumption:
final user = userContainer('user_123').value;
```

If you are using `BlocSignal` instead of raw signals, you can maintain a custom registry or map inside a parent controller, or declare a parameterized `BlocSignalProvider` in your widget tree:
```dart
BlocSignalProvider(
  create: (context) => UserBloc(userId: widget.userId),
  child: const UserView(),
)
```

---

### Gotcha 2: Provider Auto-Disposal (`.autoDispose`)
* **Riverpod**: Automatically disposes of provider state when it is no longer watched by any widget.
* **BlocSignal**: Disposal is bound to the widget tree. `BlocSignalProvider` automatically calls `close()` on the bloc it created when that provider is removed from the widget tree. If you instantiate `BlocSignal`s manually outside of a provider, you must call `close()` to release the internal resources.

---

### Gotcha 3: Side-Effects (`ref.listen` vs. `BlocSignalListener`)
* **Riverpod**: Promotes `ref.listen` within the `build` method to trigger dialogs, navigation, or snackbars.
* **BlocSignal**: Use `BlocSignalListener` in your widget tree to safely intercept state transitions and run one-off side-effects:
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

---

### Gotcha 4: Asynchronous States (`AsyncValue` vs. Sealed States)
* **Riverpod**: Wraps asynchronous states inside `AsyncValue` (`AsyncLoading`, `AsyncData`, `AsyncError`).
* **BlocSignal**: Encourages using Dart 3 sealed classes for explicit, exhaustiveness-checked pattern matching.

#### Before (Riverpod AsyncValue pattern match)
```dart
final userAsync = ref.watch(userProvider);
return userAsync.when(
  data: (user) => Text(user.name),
  loading: () => const CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

#### After (BlocSignal Sealed States pattern match)
```dart
sealed class UserState {}
class UserLoading extends UserState {}
class UserSuccess extends UserState {
  final User user;
  UserSuccess(this.user);
}
class UserFailure extends UserState {
  final String error;
  UserFailure(this.error);
}

// In the widget:
final state = context.watch<UserBloc>().stateValue;
return switch (state) {
  UserLoading() => const CircularProgressIndicator(),
  UserSuccess(:final user) => Text(user.name),
  UserFailure(:final error) => Text('Error: $error'),
};
```

---

## 3. Code Migration Comparison

### Riverpod AsyncNotifier
```dart
@riverpod
class TodoList extends _$TodoList {
  @override
  FutureOr<List<Todo>> build() async {
    return ref.watch(apiProvider).fetchTodos();
  }

  Future<void> addTodo(Todo todo) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(apiProvider).addTodo(todo);
      return ref.read(apiProvider).fetchTodos();
    });
  }
}
```

### BlocSignal Equivalent
```dart
sealed class TodoState {}
class TodoLoading extends TodoState {}
class TodoSuccess extends TodoState {
  final List<Todo> todos;
  TodoSuccess(this.todos);
}
class TodoFailure extends TodoState {
  final Object error;
  TodoFailure(this.error);
}

class TodoBloc extends BlocSignal<TodoEvent, TodoState> {
  final ApiService api;

  TodoBloc(this.api) : super(initialState: TodoLoading()) {
    on<LoadTodos>((event, emit) async {
      emit(TodoLoading());
      try {
        final todos = await api.fetchTodos();
        emit(TodoSuccess(todos));
      } catch (e) {
        emit(TodoFailure(e));
      }
    });

    on<AddTodo>((event, emit) async {
      emit(TodoLoading());
      try {
        await api.addTodo(event.todo);
        final todos = await api.fetchTodos();
        emit(TodoSuccess(todos));
      } catch (e) {
        emit(TodoFailure(e));
      }
    });
  }
}
```
