---
title: "Dart 3.13 Primary Constructors + BlocSignal: Boilerplate-Free Reactive Architecture"
published: true
description: "Discover how Dart 3.13 primary constructors, 'this' constructor bodies, and constructor shorthands transform BlocSignal into the cleanest state management architecture in Flutter."
tags: "flutter, dart, statemanagement, programming"
series: BlocSignal Architecture & Practice
---

For years, one of the most common critiques of the BLoC pattern has been **boilerplate**. 

Between declaring event classes, state hierarchies, constructor parameters, private fields, super-initializers, and event handler registries, you could easily write 50 lines of code before handling a single real-world user action.

With **Dart 3.13**, that all changes. 

Dart 3.13 brings **Primary Constructors**, **`this` constructor body blocks**, and **`new`/`factory` constructor shorthands**. When combined with **[BlocSignal](https://blocsignal.dev)**—the synchronous, signals-powered evolution of BLoC—the result is an ultra-concise, fully type-safe, and boilerplate-free state management workflow.

Let's explore how Dart 3.13 and BlocSignal fit together like hand in glove.

---

## 1. Zero-Boilerplate Events & States

In classic BLoC, defining a family of immutable events or states meant writing repeated constructor signatures and field definitions for every subtype.

### 🔴 Before Dart 3.13:
```dart
sealed class UserEvent {}

class UserFetchRequested extends UserEvent {
  final String userId;
  UserFetchRequested(this.userId);
}

class UserUpdated extends UserEvent {
  final String name;
  final int age;
  UserUpdated({required this.name, required this.age});
}

class UserLoggedOut extends UserEvent {}
```

### 🟢 With Dart 3.13 Primary Constructors:
```dart
sealed class UserEvent {}

class UserFetchRequested(final String userId) extends UserEvent;
class UserUpdated({required final String name, required final int age}) extends UserEvent;
class UserLoggedOut() extends UserEvent;
```

A whole sealed hierarchy of events or states can now be declared in just a few clean, expressive lines without losing type safety or exhaustiveness checking in `switch` expressions.

---

## 2. Streamlined Dependency Injection in `CubitSignal`

In `CubitSignal`, you typically inject repositories, API clients, or analytic trackers. In previous Dart versions, you had to declare each field, accept constructor arguments, and forward initial state to `super`.

With primary constructors, field declarations and super invocations live right in the class header.

### 🔴 Before Dart 3.13:
```dart
class UserCubit extends CubitSignal<UserState> {
  final UserRepository _repository;
  final AnalyticsService _analytics;

  UserCubit({
    required UserRepository repository,
    required AnalyticsService analytics,
    UserState initial = const UserInitial(),
  })  : _repository = repository,
        _analytics = analytics,
        super(initialState: initial);

  Future<void> loadUser(String id) async {
    emit(const UserLoading());
    try {
      final user = await _repository.fetchUser(id);
      _analytics.track('user_loaded', {'id': id});
      emit(UserSuccess(user));
    } catch (e, st) {
      onError(e, st);
      emit(UserError(e.toString()));
    }
  }
}
```

### 🟢 With Dart 3.13:
```dart
class UserCubit(
  final UserRepository repository,
  final AnalyticsService analytics, {
  final UserState initial = const UserInitial(),
}) extends CubitSignal<UserState>(initialState: initial) {

  Future<void> loadUser(String id) async {
    emit(const UserLoading());
    try {
      final user = await repository.fetchUser(id);
      analytics.track('user_loaded', {'id': id});
      emit(UserSuccess(user));
    } catch (e, st) {
      onError(e, st);
      emit(UserError(e.toString()));
    }
  }
}
```

No field re-declarations. No duplicate parameter names. The dependencies are immediately available across all methods.

---

## 3. Event Handler Registration via the `this` Block in `BlocSignal`

One of the most powerful features in Dart 3.13 is the **`this` constructor body syntax**. When using primary constructors, constructor body logic (such as registering event handlers with `on<E>()` or asserting preconditions) is placed inside a `this { ... }` block in the class body.

```dart
class SearchBloc(
  final SearchRepository repository, {
  final SearchState initial = const SearchInitial(),
}) extends BlocSignal<SearchEvent, SearchState>(initialState: initial) {

  // Dart 3.13 primary constructor body
  this {
    on<SearchQueryChanged>(
      (event, emit) async {
        if (event.query.trim().isEmpty) return emit(const SearchEmpty());
        
        emit(const SearchLoading());
        final results = await repository.search(event.query);
        emit(SearchSuccess(results));
      },
      transformer: restartable(), // Zero-stream event concurrency!
    );
  }
}
```

The header cleanly declares the class contract, and the `this` block sets up the event pipeline.

---

## 4. Immediate Reactive Wiring with `createEffect`

`BlocSignal` includes `createEffect`, which automatically tracks signal dependencies and manages teardown on container disposal. With primary constructor parameters in scope, derived cubits can synchronously wire up upstream state containers in the `this` block:

```dart
class CartSummaryCubit(final CartBloc cartBloc)
    extends CubitSignal<CartSummary>(initialState: const CartSummary.zero()) {

  this {
    // Automatically reacts to cartBloc.state signals synchronously:
    createEffect(() {
      final items = cartBloc.state.value.items;
      final total = items.fold<double>(0, (sum, item) => sum + item.price);
      emit(CartSummary(count: items.length, total: total));
    });
  }
}
```

---

## 5. Named Constructor Shorthands (`new`) for Testing & Seeding

Dart 3.13 also introduces constructor shorthands, allowing you to define secondary named constructors using `new name()` without repeating the class name:

```dart
class CounterCubit(var int count) extends CubitSignal<int>(initialState: count) {
  // Named constructor shorthands:
  new zero() : this(0);
  new seeded(int initial) : this(initial);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}
```

This makes testing variations, mock seeds, and default configurations concise and readable.

---

## 🛠️ Enabling Dart 3.13 in Your Project

To take advantage of these features:

### 1. Set the SDK Constraint in `pubspec.yaml`:
```yaml
environment:
  sdk: ^3.13.0

dependencies:
  bloc_signals: ^1.0.0
  bloc_signals_flutter: ^1.0.0
```

### 2. Enable Dart 3.13 Linter Rules in `analysis_options.yaml`:
```yaml
include: package:very_good_analysis/analysis_options.yaml

linter:
  rules:
    - use_primary_constructors
    - use_declaring_parameters
    - unnecessary_type_name_in_constructor
    - unnecessary_primary_constructor_body
```

---

## 🚀 The Architectural Payoff

By combining **Dart 3.13** language features with **BlocSignal**, you get:

1. **0ms Synchronous Updates**: State emissions propagate in the current frame without microtask delay.
2. **Minimal Ceremony**: Class headers declare fields and super initializers simultaneously.
3. **Signal Graph Efficiency**: Automatic `==` de-duplication and fine-grained UI rebuilding.
4. **Standard BLoC Rigor**: Clean event dispatching, state transitions, and OpenTelemetry observability.

## 💬 Over to You: What's Your Take?

We'd love to hear your thoughts in the comments below:

1. **How do you feel about Dart 3.13's primary constructors?** Does declaring fields directly in the class header match how you design your domain and state layers?
2. **Are you planning to adopt primary constructors across your state management classes**, or are there specific patterns where you still prefer classic constructors?
3. **Have a boilerplate-heavy state class or Bloc?** Drop a snippet in the comments, and let's see how much code Dart 3.13 and BlocSignal can shave off!

---

Ready to build boilerplate-free reactive apps? 

Check out the full documentation, benchmarks, and interactive examples at **[blocsignal.dev](https://blocsignal.dev)** or star the open-source repository on **[GitHub](https://github.com/RandalSchwartz/BlocSignal)**!
