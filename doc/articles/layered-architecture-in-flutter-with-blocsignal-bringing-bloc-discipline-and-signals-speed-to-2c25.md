---
series: "BlocSignal Architecture & Practice"
title: "Layered Architecture in Flutter with BlocSignal: Bringing BLoC Discipline and Signals Speed to CodeWithAndrea’s Pattern"
published: true
description: "Learn how to adapt CodeWithAndrea's classic 4-layer Flutter architecture (Domain, Data, Application, Presentation) using BlocSignal for synchronous reactivity, instant hydration, and clean code."
tags: flutter, dart, architecture, statemanagement

---

## Clean, Predictable, and Fine-Grained Reactivity Across All Four Layers of Your Application

Whether you are building a small side project or an enterprise Flutter application, structuring your codebase into clean, decoupled layers is the single best investment you can make for long-term maintainability.

For years, one of the finest reference guides for Flutter architecture has been **Andrea Bizzotto’s** ([CodeWithAndrea.com](https://codewithandrea.com)) classic series on [Flutter Application Architecture](https://codewithandrea.com/articles/flutter-app-architecture-application-layer/). It is a masterpiece of pragmatic software design. Whenever developers ask me how to structure large-scale Flutter applications, Andrea’s 4-layer architecture guide—spanning **Domain**, **Data**, **Application**, and **Presentation**—is the exact resource I point them to.

Originally designed around Riverpod and standard state containers, Andrea's pattern provides a clear separation of concerns. But as Flutter state management has evolved, developers are seeking ways to combine **the structural discipline and event traceability of BLoC** with **the fine-grained, synchronous speed of modern signals**.

Enter **[`BlocSignal`](https://pub.dev/packages/bloc_signals)**.

In this article, we adapt Andrea’s proven 4-layer architecture to `BlocSignal`. We’ll explore how `BlocSignal` simplifies each layer by replacing microtask queue latency with synchronous frame propagation, eliminating callback spaghetti with declarative `computed()` dependency graphs, and bringing instant Frame 1 state hydration to offline-first apps.

---

## 🏗️ The 4-Layer Architecture Overview

In a clean layered architecture, dependencies point strictly **inward** toward the Domain layer, while data flows in a clean unidirectional loop:

```plaintext
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                    │
│    (Widgets, Screens, CubitSignal / BlocSignal)        │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                    Application Layer                    │
│      (Service Classes, Derived computed() Signals)      │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                       Data Layer                        │
│   (Repositories, Data Sources, Hydrated Storage)        │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                      Domain Layer                       │
│    (Entities, Value Objects, AsyncState<T>, Rules)      │
└────────────────────────────┴────────────────────────────┘
```

Each layer has a single, well-defined responsibility:
1. **Domain Layer:** Pure Dart entities, immutable models, and asynchronous state representations (`AsyncState<T>`).
2. **Data Layer:** Repositories, API data sources, and local persistent caching (`bloc_signals_hydrate`).
3. **Application Layer:** Service classes coordinating multi-repository transactions and reactive `computed()` / `futureSignal()` business logic.
4. **Presentation Layer:** State controllers (`CubitSignal`/`BlocSignal`) and fine-grained Flutter UI widgets (`BlocSignalBuilder`, `signal.watch()`, `context.select()`).

Let's examine how to build each layer with `BlocSignal`.

---

## 1. The Domain Layer: Pure Entities & Async State

The **Domain Layer** contains the core business models and data structures of your application. It must remain 100% pure Dart—free from Flutter UI dependencies, HTTP clients, or database drivers.

### Modeling Domain Entities
In `BlocSignal`, state containers automatically de-duplicate emissions when `newState == oldState`. By implementing proper equality contracts (using standard Dart `==`, `equatable`, or `freezed`), downstream UI rebuilds and reactive computations are automatically skipped in `O(1)` time whenever data doesn't change.

```dart
// domain/cart_item.dart
import 'package:meta/meta.dart';

@immutable
class CartItem {
  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String id;
  final String name;
  final double price;
  final int quantity;

  double get total => price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          quantity == other.quantity;

  @override
  int get hashCode => Object.hash(id, quantity);
}
```

### Representing Asynchronous State (`AsyncState<T>`)
When operations involve network requests or database reads, state models need to represent **loading**, **data**, and **error** states cleanly. 

`BlocSignal` provides `AsyncState<T>` (with sealed variants `AsyncData`, `AsyncLoading`, and `AsyncError`), making async state modeling intuitive for UI layers:

```dart
// domain/user_profile.dart
import 'package:bloc_signals/bloc_signals.dart';

typedef UserProfileState = AsyncState<UserProfile>;

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
  });

  final String id;
  final String email;
  final String name;
}
```

---

## 2. The Data Layer: Repositories & Instant Hydration

The **Data Layer** is responsible for fetching, storing, and persisting data from external sources (REST APIs, GraphQL, Firebase, SQLite).

### Repositories
Repositories hide network or database complexities behind clean interfaces:

```dart
// data/auth_repository.dart
import '../domain/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> fetchCurrentUser();
  Future<void> signOut();
}

class ApiAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> fetchCurrentUser() async {
    // Simulated REST API fetch
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const UserProfile(
      id: 'usr_101',
      email: 'alex@example.com',
      name: 'Alex Developer',
    );
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
```

### Offline Caching & Frame 1 Hydration (`bloc_signals_hydrate`)
Standard stream-based state containers often suffer from "initial startup flicker" because state restoration runs asynchronously after the first UI render pass. 

With `bloc_signals_hydrate`, `HydratedCubitSignal` hydrates state **synchronously during object construction**. Your cached offline data renders on frame 1 without loading spinners or layout jumps.

### Eliminating Try/Catch Boilerplate with `futureSignal`
Even inside Cubit async methods, you don't need to write repetitive `try / catch / emit(AsyncLoading()) / emit(AsyncData())` blocks. 

By creating a **`futureSignal()`**, the signal automatically transitions through `AsyncLoading` → `AsyncData` or `AsyncError`. Subscribing `emit` to the `futureSignal` and returning `s.future` gives you zero try/catch code while letting UI callers (like pull-to-refresh widgets) await the returned `Future`:

```dart
// data/user_session_cubit.dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import '../domain/user_profile.dart';
import 'auth_repository.dart';

class UserSessionCubit extends HydratedCubitSignal<UserProfileState> {
  UserSessionCubit(this._authRepository) : super(const AsyncLoading());

  final AuthRepository _authRepository;

  Future<UserProfile> loadUser() {
    // 1. futureSignal handles AsyncLoading -> AsyncData / AsyncError automatically
    final s = futureSignal(() => _authRepository.fetchCurrentUser());

    // 2. Subscribe state emissions directly to the futureSignal's AsyncState
    s.subscribe((asyncState) => emit(asyncState));

    // 3. Return s.future so callers (e.g. RefreshIndicator) can await completion!
    return s.future;
  }

  @override
  UserProfileState? fromJson(dynamic json) {
    // Elegant Dart 3 map pattern matching (zero manual casting required!)
    return switch (json) {
      {
        'id': String id,
        'email': String email,
        'name': String name,
      } => AsyncData(UserProfile(id: id, email: email, name: name)),
      _ => null,
    };
  }

  @override
  dynamic toJson(UserProfileState state) {
    return switch (state) {
      AsyncData(:final value) => {
          'id': value.id,
          'email': value.email,
          'name': value.name,
        },
      _ => null,
    };
  }
}
```

---

## 3. The Application Layer: Services & Declarative `computed()` Signals

The **Application Layer** (Service Layer) coordinates multi-repository transactions and encapsulates cross-cutting business rules. 

### Eliminating Manual Callback Spaghetti with `computed()`
In traditional architectures, service classes require manual listener subscriptions, stream transformers, or manual disposal teardowns to keep multi-repository states in sync. 

In `BlocSignal`, services leverage fine-grained `computed()` signals declared cleanly as `late final` properties. Derived values calculate lazily and update automatically with zero manual listener management:

```dart
// application/checkout_service.dart
import 'package:bloc_signals/bloc_signals.dart';
import '../domain/cart_item.dart';
import '../domain/user_profile.dart';
import '../data/user_session_cubit.dart';

class CheckoutService {
  CheckoutService({
    required this.cartItemsSignal,
    required this.userSessionCubit,
  });

  final ReadonlySignal<List<CartItem>> cartItemsSignal;
  final UserSessionCubit userSessionCubit;

  // Declarative inline computed signals across multiple layers
  late final subtotalSignal = computed(() {
    final items = cartItemsSignal.value;
    return items.fold<double>(0, (sum, item) => sum + item.total);
  });

  late final taxSignal = computed(() {
    // 8% tax applied to subtotal
    return subtotalSignal.value * 0.08;
  });

  late final grandTotalSignal = computed(() {
    return subtotalSignal.value + taxSignal.value;
  });

  late final isEligibleForCheckoutSignal = computed(() {
    final hasItems = cartItemsSignal.value.isNotEmpty;
    final isAuthenticated = userSessionCubit.stateValue is AsyncData<UserProfile>;
    return hasItems && isAuthenticated;
  });
}
```

> 💡 **Why is no `dispose()` method needed?**
> In classic Rx streams or `ValueNotifier`, calling `.listen()` or `.addListener()` inside a service creates permanent subscription links that leak memory unless manually cancelled via a `dispose()` method.
> 
> Signals work differently: a `computed()` signal is **lazy and self-tearing-down**. It only subscribes to its upstream dependencies (`cartItemsSignal`, `userSessionCubit.state`) while downstream UI widgets are actively watching it. The moment widgets unmount and subscriber counts hit zero, `computed()` automatically detaches its listeners from upstream sources. No `dispose()`, no `StreamSubscription.cancel()`, and zero memory leaks.

---

## 4. The Presentation Layer: Controllers & Surgical UI Rebuilds

The **Presentation Layer** consists of state controllers (`CubitSignal` or `BlocSignal`) and Flutter UI widgets.

### Choosing Between `CubitSignal` and `BlocSignal`
* **`CubitSignal`:** Ideal for direct method-driven state updates (e.g., `cartCubit.addItem(...)`).
* **`BlocSignal`:** Ideal for complex event-driven workflows requiring streamless event transformers (`droppable()`, `sequential()`, `restartable()`, or custom `Mutex` locks).

```dart
// presentation/cart_cubit.dart
import 'package:bloc_signals/bloc_signals.dart';
import '../domain/cart_item.dart';

class CartCubit extends CubitSignal<List<CartItem>> {
  CartCubit() : super(const []);

  void addItem(CartItem item) {
    final existingIndex = stateValue.indexWhere((i) => i.id == item.id);
    if (existingIndex >= 0) {
      final updated = List<CartItem>.from(stateValue);
      final current = updated[existingIndex];
      updated[existingIndex] = current.copyWith(quantity: current.quantity + 1);
      emit(updated);
    } else {
      emit([...stateValue, item]);
    }
  }

  void removeItem(String id) {
    emit(stateValue.where((item) => item.id != id).toList());
  }
}
```

### Automatic Error Routing & Operational Resilience
In `BlocSignal`, asynchronous event handlers (`FutureOr<void>`) automatically capture operational runtime exceptions and route them to `onError` and active telemetry observers (such as `OtelBlocSignalObserver` or `DevToolsBlocSignalObserver`). Programmer faults fail fast, while business exceptions transition safely without crashing the UI.

### Surgical UI Binding (`signal.watch`)
In Flutter widgets, `BlocSignal` integrates natively with `package:bloc_signals_flutter`. Any widget holding a reference to a service, Cubit, or signal (via constructor injection, `GetIt`, or Riverpod) can simply call `signal.watch(context)` to subscribe to surgical, fine-grained rebuilds:

```dart
// presentation/checkout_screen.dart
import 'package:flutter/material.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import '../application/checkout_service.dart';
import 'cart_cubit.dart';

class CheckoutSummaryWidget extends StatelessWidget {
  const CheckoutSummaryWidget({
    super.key,
    required this.cartCubit,
    required this.checkoutService,
  });

  final CartCubit cartCubit;
  final CheckoutService checkoutService;

  @override
  Widget build(BuildContext context) {
    // 1. Watch CartCubit state signal directly (no InheritedWidget lookup needed!)
    final cartItems = cartCubit.state.watch(context);
    final cartItemCount = cartItems.fold<int>(0, (sum, i) => sum + i.quantity);

    // 2. Watch computed signals from CheckoutService
    final grandTotal = checkoutService.grandTotalSignal.watch(context);
    final isEligible = checkoutService.isEligibleForCheckoutSignal.watch(context);

    return Column(
      children: [
        Text(
          'Total ($cartItemCount items): \$${grandTotal.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: isEligible ? () => _processOrder(context) : null,
          child: const Text('Complete Purchase'),
        ),
      ],
    );
  }

  void _processOrder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order placed successfully!')),
    );
  }
}
```

> 💡 **Dependency Injection Freedom: Why `BlocSignalProvider` is Optional**
> In classic BLoC or `package:provider`, widgets *must* look up state containers from the `BuildContext` tree using `InheritedWidget` (`BlocProvider.of(context)`).
> 
> In `BlocSignal`, because signals manage their own fine-grained subscriptions internally, any widget holding a reference to a signal or service (via constructor injection, `GetIt`, or Riverpod) can simply call `signal.watch(context)`. You are free to use constructor passing, service locators, or `BlocSignalProvider`—the framework never forces a rigid UI tree setup on you.

---

## 5. Testing Each Layer Deterministically

One of the greatest benefits of synchronous signal propagation is **deterministic unit testing**. 

In stream-based BLoCs, testing asynchronous microtask queues requires `await pump()` or delayed stream draining. In `BlocSignal`, state propagation is synchronous. Combined with `package:bloc_signals_test`, unit testing across all 4 layers executes instantly without non-deterministic timing flakiness:

```dart
// test/application/checkout_service_test.dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_signals/bloc_signals.dart';
import '../../data/user_session_cubit.dart';
import '../../domain/cart_item.dart';
import '../../application/checkout_service.dart';

void main() {
  group('CheckoutService Layer Integration Tests', () {
    late CartCubit cartCubit;
    late UserSessionCubit userSessionCubit;
    late CheckoutService checkoutService;

    setUp(() {
      cartCubit = CartCubit();
      userSessionCubit = UserSessionCubit(MockAuthRepository());
      checkoutService = CheckoutService(
        cartItemsSignal: cartCubit.state,
        userSessionCubit: userSessionCubit,
      );
    });

    tearDown(() async {
      await cartCubit.close();
      await userSessionCubit.close();
    });

    test('calculates subtotal, tax, and grand total synchronously on item addition', () {
      expect(checkoutService.subtotalSignal.value, equals(0.0));

      cartCubit.addItem(const CartItem(
        id: 'p1',
        name: 'Dart T-Shirt',
        price: 20.0,
        quantity: 2,
      ));

      // Synchronous assertions—no await pump() required!
      expect(checkoutService.subtotalSignal.value, equals(40.0));
      expect(checkoutService.taxSignal.value, equals(3.20));
      expect(checkoutService.grandTotalSignal.value, equals(43.20));
    });
  });
}
```

---

## 🎯 Summary & Key Takeaways

Adapting **Andrea Bizzotto’s 4-Layer Architecture** to `BlocSignal` gives you the best of both worlds:

1. **Domain Layer:** Clean, pure Dart models with `O(1)` equality de-duplication and expressive `AsyncState<T>` modeling.
2. **Data Layer:** Instant Frame 1 offline hydration via `bloc_signals_hydrate` with zero startup flicker.
3. **Application Layer:** Declarative, leak-free business logic using `computed()` and `futureSignal()` across multiple repositories with zero try/catch or teardown boilerplate.
4. **Presentation Layer:** BLoC event discipline with fine-grained UI rebuilds via `signal.watch()`—with zero `BlocSignalProvider` or `BuildContext` requirements!
5. **Testing:** Instant, 100% deterministic unit testing with `bloc_signals_test`.

### Links & Resources
* 📖 Read Andrea Bizzotto’s original reference: [CodeWithAndrea — Flutter App Architecture](https://codewithandrea.com/articles/flutter-app-architecture-application-layer/)
* 📦 Package on Pub.dev: [`bloc_signals`](https://pub.dev/packages/bloc_signals)
* 🐙 GitHub Repository: [`RandalSchwartz/BlocSignal`](https://github.com/RandalSchwartz/BlocSignal)
