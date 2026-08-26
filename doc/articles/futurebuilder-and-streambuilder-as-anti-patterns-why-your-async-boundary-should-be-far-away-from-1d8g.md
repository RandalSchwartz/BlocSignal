---
series: "BlocSignal Architecture & Practice"
title: "FutureBuilder and StreamBuilder as Anti-Patterns: Why Your Async Boundary Should Be Far Away From Your Views"
published: true
description: "Discover why using FutureBuilder and StreamBuilder inside Flutter widget trees breaks separation of concerns, triggers accidental refetches, creates layout shift cascades, and hinders testability—and learn how to quarantine async at the perimeter using AsyncSignal and BlocSignal."
tags: flutter, dart, architecture, statemanagement

---

## Why Raw Asynchrony Inside the Presentation Layer Breaks Separation of Concerns, User Experience, and Testability

Every Flutter developer remembers the magic of their first `FutureBuilder`.

You paste an HTTP request directly into a `FutureBuilder` inside your widget's `build()` method, configure a `CircularProgressIndicator` for `ConnectionState.waiting`, render your data in `ConnectionState.done`, and suddenly your app is alive with real-time data in fewer than twenty lines of code.

It feels like superpowers. The official documentation features it. Introductory tutorials celebrate it.

And then your application grows.

Suddenly, users report that typing into a text field causes the entire screen to reload and fetch fresh data from the server. Opening the keyboard triggers duplicate network requests. Sibling widgets flicker and jump across the screen as independent async calls resolve out of order. And writing automated widget tests turns into an exhausting battle with `tester.pumpAndSettle()`, fake async timers, and microtask queues.

This problem happened often enough across the Flutter community that I recorded a video explaining why it happens and how to fix it: [**Why you shouldn't put FutureBuilder in your build method**](https://youtu.be/sqE-J8YJnpg). In fact, the very first version of the official Flutter `FutureBuilder` documentation video got this exact pattern wrong by instantiating the future inside `build()`, until I filed an issue against the Flutter repository to get it corrected (the current official video on the Flutter YouTube channel even prominently displays "Take 2" on the clapperboard as proof!).

What began as a helpful convenience widget quickly turns into an architectural trap.

In this article, we examine why `FutureBuilder` and `StreamBuilder` are architectural anti-patterns when used for application state, explore the **four fatal flaws of in-view asynchrony**, and demonstrate how to push asynchronous boundaries to the edge of your architecture using **`AsyncSignal`**, **`CubitSignal`**, and **`BlocSignal`**.

---

## 🚨 The Core Problem: The Failure of In-View Asynchrony

To understand why `FutureBuilder` fails at scale, we must return to the foundational principle of Flutter UI engineering:

> ### **UI = ƒ(State)**

Flutter widgets are designed to be **pure, synchronous projections of state**. Given a snapshot of data at time *t*, a widget function should execute synchronously, instantiate a subtree of render objects, and return immediately.

When you drop a `FutureBuilder` or `StreamBuilder` directly into your widget tree, you violate this contract. You introduce raw time, transport mechanics, and asynchronous lifecycle orchestration directly into the presentation layer.

Let us break down the four fatal flaws that emerge from this architectural choice.

```plaintext
┌─────────────────────────────────────────────────────────┐
│               The In-View Asynchrony Trap               │
│                                                         │
│  Widget.build()                                         │
│    │                                                    │
│    ├──> Instantiates Future on every build frame ⚠️      │
│    ├──> Orchestrates ConnectionState & HTTP errors ⚠️   │
│    ├──> Triggers uncoordinated layout shifts ⚠️          │
│    └──> Requires multi-pump async widget tests ⚠️       │
└─────────────────────────────────────────────────────────┘
```

---

### 1. Layering Collapse & State Management via Widgets

In a clean layered architecture (such as Domain ← Data ← Application ← Presentation), the presentation layer has exactly one job: **translating domain state into visual UI elements**.

When a widget embeds a `FutureBuilder`, that widget suddenly takes on massive orchestration responsibilities:
- **Connection State Management:** Manually inspecting `snapshot.connectionState == ConnectionState.waiting`, `ConnectionState.active`, and `ConnectionState.done`.
- **Error & Exception Handling:** Decoding HTTP 500 errors, socket timeouts, and parsing exceptions inside `if (snapshot.hasError)`.
- **Caching & Retention:** Deciding whether previous data should remain visible while a refresh is in progress or wiped out in favor of a spinner.
- **Retry Coordination:** Wiring reload buttons that must somehow re-trigger the widget's internal asynchronous future.

Your presentation widgets are no longer views; they have become ad-hoc state managers and network controllers.

---

### 2. The Re-Execution & Accidental Refetch Trap

Consider the most common bug written by junior and intermediate Flutter developers:

```dart
// ❌ ANTI-PATTERN: Re-executing network calls on every rebuild
class UserProfileView extends StatelessWidget {
  const UserProfileView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      // ⚠️ DANGER: Called on EVERY build frame!
      future: httpApiClient.fetchProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        return ProfileContent(profile: snapshot.data!);
      },
    );
  }
}
```

Whenever this widget's parent rebuilds—whether because an ancestor animated, a theme changed, the device rotated, or the software keyboard opened—Flutter calls `build()`.

Every invocation of `build()` creates a **brand-new `Future` instance**. The previous request is abandoned, a new HTTP request is dispatched across the network, and the UI immediately flashes back to `CircularProgressIndicator`.

#### The Flawed "StatefulWidget Fix"
Developers often attempt to patch this by converting the view to a `StatefulWidget` and caching the future in `initState()`:

```dart
// ⚠️ NOISY WORKAROUND: Bloating the UI with lifecycle ceremony
class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  late Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = httpApiClient.fetchProfile(widget.userId);
  }

  @override
  void didUpdateWidget(UserProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _profileFuture = httpApiClient.fetchProfile(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        /* ... */
      },
    );
  }
}
```

While this prevents duplicate fetches on rebuild, look at the architectural cost:
1. You have introduced mutable lifecycle state (`_profileFuture`, `initState`, `didUpdateWidget`) into what should have been a simple display widget.
2. The data is trapped inside private widget state `_UserProfileViewState`. Sibling widgets, app bars, and global analytics cannot read or coordinate with this data.
3. If the user navigates away and returns, the state is destroyed and refetched from scratch.

---

### 3. Uncoordinated UI Cascades & Layout Shift (The "Spinner Storm")

Real-world applications rarely fetch a single piece of data on a screen. A dashboard might require user profile information, unread notifications, recent transactions, and recommended items.

When each of these sections manages its own `FutureBuilder` or `StreamBuilder`, they resolve asynchronously at unpredictable microtask intervals.

```plaintext
Frame 1:  [ Profile Spinner ]   [ Notifications Spinner ]   [ Orders Spinner ]
Frame 12: [ Profile Header  ]   [ Notifications Spinner ]   [ Orders Spinner ]  <-- Layout Shift!
Frame 19: [ Profile Header  ]   [ Notifications (0)     ]   [ Orders Spinner ]  <-- Layout Shift!
Frame 34: [ Profile Header  ]   [ Notifications (0)     ]   [ Orders List    ]  <-- Layout Shift!
```

This causes what designers call **The Spinner Storm**:
- Intermediate progress indicators flash and pop independently.
- Content jumps vertically as sections expand at varying millisecond timestamps (causing severe Cumulative Layout Shift).
- If one child request fails with an error, half the screen renders data while the other half renders an isolated red error banner.

---

### 4. Untestable Views & Async Pump Gymnastics

Try writing a widget test for a screen populated with `FutureBuilder` widgets:

```dart
// ❌ FRAGILE & SLOW: Async pump loops and timing dependencies
testWidgets('renders user profile after loading', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: UserProfileView(userId: 'user-123'),
    ),
  );

  // Expect loading indicator
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Must drain microtasks and wait for asynchronous network mocks
  await tester.pumpAndSettle();

  // Expect content
  expect(find.text('Jane Doe'), findsOneWidget);
});
```

Because the widget itself creates and awaits the `Future`, your widget test cannot simply supply data to the view. Instead, your test must:
1. Mock the low-level HTTP client or transport layer.
2. Carefully drain microtasks and fake timers with `tester.pumpAndSettle()`.
3. Suffer from flaky CI runs when asynchronous timers fail to settle within arbitrary timeouts.

---

## 🛡️ The Architectural Solution: Async at the Edge, Synchronous in the Core

The solution to in-view asynchrony is straightforward:

> **Push the asynchronous boundary as far away from the presentation layer as possible. Quarantine raw I/O strictly at the infrastructure perimeter, coordinate state in pure domain controllers, and deliver deterministic, synchronous states to the views.**

```plaintext
┌─────────────────────────────────────────────────────────┐
│               External I/O Perimeter                    │
│   (REST APIs, WebSockets, Databases, Hardware Sensors)  │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│              Data & Repository Layer                    │
│   (AsyncSignal / FutureSignal / StreamSignal / .$)      │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                Domain & Logic Layer                     │
│    (CubitSignal / BlocSignal — Synchronous Core)        │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼ (Synchronous 0ms Frame Propagation)
┌─────────────────────────────────────────────────────────┐
│                 Presentation Layer                      │
│    (BlocSignalBuilder / context.select() / Pure UI)     │
└─────────────────────────────────────────────────────────┘
```

In this architecture:
1. **The Data Layer** wraps asynchronous operations in reactive signals (`FutureSignal`, `StreamSignal`, or the concise `.$` extension).
2. **The Domain Layer (`CubitSignal` / `BlocSignal`)** coordinates these edge signals, manages caching and error boundaries, and emits explicit, immutable state models (`AsyncState<T>`).
3. **The Presentation Layer** binds to state **synchronously**. It never touches a `Future` or `Stream`. On any given frame, the widget reads the current state snapshot and returns its widget tree with zero latency.

---

## 💡 Step-by-Step Implementation with BlocSignal

Let us walk through building a complete, production-grade profile screen using this pattern.

---

### Step 1: Async at the Edge (Data & Repository Layer)

At the repository perimeter, we wrap raw asynchronous futures or streams using `futureSignal`, `streamSignal`, or the `.toSignal()` extension:

```dart
// data/user_repository.dart
import 'package:signals_core/signals_core.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}

abstract class UserRepository {
  FutureSignal<UserProfile> getProfile(String userId);
}

class HttpUserRepository implements UserRepository {
  const HttpUserRepository({required this.apiClient});

  final ApiClient apiClient;

  @override
  FutureSignal<UserProfile> getProfile(String userId) {
    // Quarantine async promise into a reactive FutureSignal at the edge
    return futureSignal(() => apiClient.fetchUserProfile(userId));
    
    // 💡 Shorthand alternative: You can also use the concise .toSignal() extension!
    // return apiClient.fetchUserProfile(userId).toSignal();
  }
}
```

Notice what happens here:
- `HttpUserRepository` returns a `FutureSignal<UserProfile>`.
- The async I/O is wrapped at the perimeter. Downstream consumers can read the current `AsyncState<UserProfile>` synchronously at any time via `signal.value` without awaiting a `Future`.
- **Ultra-concise ergonomics:** In addition to `futureSignal(...)`, `signals_core` provides clean extension shorthands: use `.toSignal()` on any `Future` or `Stream` (such as `apiClient.fetchUserProfile(userId).toSignal()`) to lift async primitives into reactive signals, and `.$` on standard values (such as `0.$` or `'initial'.$`) for instant signal creation.

#### 💡 The Hidden Superpower: Built-In `try/catch` Encapsulation

Consider how much repetitive plumbing developers typically write for every single HTTP endpoint:

```dart
// 😩 THE OLD CEREMONY: Manual try/catch boilerplate for EVERY endpoint
Future<void> fetchProfile() async {
  emit(const ProfileLoading());
  try {
    final profile = await apiClient.fetchProfile(userId);
    emit(ProfileLoaded(profile));
  } catch (error, stackTrace) {
    emit(ProfileError(error.toString()));
  }
}
```

If you forget that `try/catch` block on even one endpoint, an unexpected socket failure, DNS error, or HTTP 500 will bubble up as an unhandled asynchronous exception and crash your isolate.

`futureSignal` eliminates this entire class of errors. Under the hood, `futureSignal` automatically runs the callback inside a built-in `try/catch` quarantine:
1. **Automatic Error Containment:** Any network timeout, bad status code, or JSON parsing exception is caught at the perimeter and converted into an `AsyncError<T>(error, stackTrace)`.
2. **Zero Uncaught Promise Rejections:** You never have unhandled asynchronous exceptions crashing the isolate or polluting terminal logs.
3. **Deterministic State Modeling:** The error and its stack trace become first-class data inside the synchronous `AsyncState` snapshot, ready to be pattern-matched downstream with zero boilerplate.

---

### Step 2: Clean State Coordination in `CubitSignal` (Domain Layer)

Next, our domain state container (`CubitSignal`) consumes the edge signal. It manages user intents (such as manual refreshing) and exposes the current `AsyncState` to the UI:

#### Traditional Dart 3.5 Syntax:
```dart
// domain/profile_cubit.dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';

class ProfileCubit extends CubitSignal<AsyncState<UserProfile>> {
  ProfileCubit({
    required UserRepository repository,
    required String userId,
  })  : _profileSignal = repository.getProfile(userId),
        super(initialState: const AsyncState.loading()) {
    // Synchronously propagate state changes whenever the edge signal emits
    createEffect(() => emit(_profileSignal.value));
  }

  final FutureSignal<UserProfile> _profileSignal;

  /// Refreshes the profile by triggering the edge signal's reload
  void refresh() => _profileSignal.refresh();
}
```

#### Modern Dart 3.13 Syntax (Primary Constructor):
```dart
// domain/profile_cubit.dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';

class ProfileCubit(
  UserRepository repository, {
  required String userId,
}) : super(initialState: const AsyncState.loading()) {
  final _profileSignal = repository.getProfile(userId);

  this {
    createEffect(() => emit(_profileSignal.value));
  }

  void refresh() => _profileSignal.refresh();
}
```

---

### Step 3: Pure Synchronous Rendering in the View (Presentation Layer)

Now, look at the presentation view. The view contains **zero** asynchronous code. It does not know what an HTTP request is, it does not manage `ConnectionState`, and it cannot accidentally re-trigger network calls:

```dart
// presentation/profile_view.dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ProfileCubit>().refresh(),
          ),
        ],
      ),
      body: BlocSignalBuilder<ProfileCubit, AsyncState<UserProfile>>(
        builder: (context, state) {
          return state.map(
            data: (profile) => ProfileDetailsCard(profile: profile),
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load profile: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.read<ProfileCubit>().refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileDetailsCard extends StatelessWidget {
  const ProfileDetailsCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(profile.email, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
```

#### 🛡️ The True Decoupling Test: Zero Presentation Changes on Transport Swaps

Notice what this architectural separation achieves: if you decide to completely change how profiles are fetched—for example replacing the edge `futureSignal` with a real-time WebSocket `streamSignal`, a local SQLite database query, or a manual `CubitSignal` method that imperatively transitions an `AsyncState` from loading to data—**not a single line of presentation code in `ProfileView` has to change**.

By contrast, with `FutureBuilder`, you cannot switch to a stream without completely replacing the widget with `StreamBuilder`, and you cannot switch to a synchronous cache without faking artificial `Future.value(...)` / `Completer` wrappers just to satisfy the widget's API.

The `BlocSignal` view depends strictly on the immutable contract of `AsyncState<UserProfile>`. Transport mechanics, caching strategies, network protocols, and retry policies can evolve independently behind the domain boundary without touching your UI widgets.

#### 🧹 Zero Manual Dispose Management: Complete Owner-Managed Lifecycles

And notice something equally remarkable: **there is no dispose management anywhere in this code**. Everything is completely managed by its owner.

In traditional Flutter architectures using streams, `ChangeNotifier`, or raw state controllers, developers spend an enormous amount of time writing defensive teardown code: canceling `StreamSubscription` instances, detaching listeners, and debugging subtle memory leaks when a view is popped from the navigator.

In `BlocSignal`, lifecycle ownership is completely automatic:
1. **Effects are owned by the Cubit:** The `createEffect` registered inside `ProfileCubit` is bound to the cubit's reactive scope and is automatically disposed when `cubit.close()` executes.
2. **Views are pure and stateless:** `ProfileView` is a clean `StatelessWidget`. It holds no subscriptions, maintains no mutable state, and requires zero `dispose()` boilerplate.
3. **Providers manage container lifecycles:** When `ProfileCubit` is provided by `BlocSignalProvider`, the provider automatically calls `close()` when the widget subtree unmounts from the element tree.

You get leak-free, frame-accurate reactivity with zero manual disposal ceremony.

---

## ⚖️ Side-by-Side Comparison: Before vs. After

Let us compare the two architectures across every critical engineering metric:

| Metric | `FutureBuilder` In-View (Anti-Pattern) | `BlocSignal` Async at Edge (Clean Architecture) |
| :--- | :--- | :--- |
| **Widget Responsibility** | Orchestrates I/O, handles HTTP errors, manages connection state | Pure visual projection of synchronous state |
| **Rebuild Safety** | Re-executes network call on every frame unless wrapped in `StatefulWidget` | 100% safe; rebuilds only read the current synchronous value |
| **State Sharing** | Trapped in local widget subtree; impossible to share with app bar or sibling views | Accessible across the subtree or globally via `CubitSignal` / `BlocSignal` |
| **UI Coordination** | Uncoordinated layout shifts and independent spinner flicker | Synchronized state transitions; coordinated multi-signal computed graphs |
| **Unit Testing** | Requires mock HTTP servers and asynchronous `tester.pumpAndSettle()` | Instant, synchronous testing with `blocSignalTest` and 0ms widget assertions |

---

## 🧪 Testing Contrast: Instant Determinism vs. Async Gymnastics

One of the greatest benefits of pushing the async boundary to the edge is how testing is transformed.

### 1. Unit Testing Domain Logic with `blocSignalTest`
Because `CubitSignal` manages state transitions deterministically, we can unit test our business logic with `blocSignalTest` in pure Dart with zero Flutter dependencies:

```dart
// test/profile_cubit_test.dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class FakeUserRepository implements UserRepository {
  FakeUserRepository({required this.profileSignal});

  final FutureSignal<UserProfile> profileSignal;

  @override
  FutureSignal<UserProfile> getProfile(String userId) => profileSignal;
}

void main() {
  group('ProfileCubit', () {
    const testUser = UserProfile(
      id: 'usr_1',
      name: 'Alice Smith',
      email: 'alice@example.com',
    );

    test('initial state is AsyncState.loading', () {
      final fakeSignal = futureSignal<UserProfile>(() async => testUser);
      final repo = FakeUserRepository(profileSignal: fakeSignal);
      final cubit = ProfileCubit(repository: repo, userId: 'usr_1');

      expect(cubit.stateValue, isA<AsyncLoading<UserProfile>>());
      cubit.close();
    });

    blocSignalTest<ProfileCubit, AsyncState<UserProfile>>(
      'emits AsyncData when edge signal resolves successfully',
      build: () {
        final fakeSignal = futureSignal<UserProfile>(() async => testUser);
        final repo = FakeUserRepository(profileSignal: fakeSignal);
        return ProfileCubit(repository: repo, userId: 'usr_1');
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        isA<AsyncLoading<UserProfile>>(),
        predicate<AsyncState<UserProfile>>(
          (state) => state.value == testUser,
          'contains testUser data',
        ),
      ],
    );
  });
}
```

### 2. Instant Synchronous Widget Testing
When testing the presentation view, we do not need to mock network clients, fake HTTP latency, or call `tester.pumpAndSettle()`. We simply inject a mock or fake `ProfileCubit` emitting a synchronous state and assert the rendered widget tree in **Frame 1**:

```dart
// test/profile_view_test.dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_core/signals_core.dart';

class MockProfileCubit extends CubitSignal<AsyncState<UserProfile>> {
  MockProfileCubit(super.initialState);

  void emitState(AsyncState<UserProfile> state) => emit(state);
}

void main() {
  testWidgets('renders user details immediately when state is AsyncData', (tester) async {
    const user = UserProfile(
      id: 'usr_1',
      name: 'Alice Smith',
      email: 'alice@example.com',
    );

    final mockCubit = MockProfileCubit(const AsyncState.data(user));

    await tester.pumpWidget(
      MaterialApp(
        home: BlocSignalProvider<MockProfileCubit>.value(
          value: mockCubit,
          child: const ProfileView(),
        ),
      ),
    );

    // Assert immediately in Frame 1 with NO pumpAndSettle delay!
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('renders error banner and retry button when state is AsyncError', (tester) async {
    final mockCubit = MockProfileCubit(
      AsyncState.error(Exception('Network timeout'), StackTrace.empty),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocSignalProvider<MockProfileCubit>.value(
          value: mockCubit,
          child: const ProfileView(),
        ),
      ),
    );

    expect(find.textContaining('Network timeout'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
```

Look at the difference:
- **0ms execution time:** The widget test runs in a single synchronous tick without draining microtask queues.
- **Zero flakiness:** No timers, no race conditions, no unhandled async rejections.
- **Pure UI verification:** The test proves that the UI correctly projects state into pixels, without conflating UI verification with network protocol testing.

---

## 🎯 Four Non-Negotiable Rules for Async Flutter Architecture

To maintain clean, scalable Flutter applications, enforce these four golden rules across your team:

1. **Never Instantiate or Await a `Future` or `Stream` Inside `Widget.build()`:** Widgets are synchronous projectors of state. If a widget is constructing a future, your architecture has a layering leak.
2. **Quarantine Asynchrony at the Repository Perimeter:** Wrap remote APIs, databases, and device sensors in `AsyncSignal` (`futureSignal`, `streamSignal`, or `.$`) at the data layer boundary.
3. **Coordinate State in Domain Containers:** Use `CubitSignal` for straightforward feature state and `BlocSignal` for complex, event-driven pipelines. Expose synchronous state models (`AsyncState<T>` or sealed class hierarchies) to the presentation layer.
4. **Bind Pure Synchronous Views with `BlocSignalBuilder`:** Use `BlocSignalBuilder` or `context.select()` to read synchronous snapshots. Let the framework handle de-duplication and granular widget updates.

By keeping your async boundaries at the edge and your core synchronous, your Flutter views remain simple, your state transitions remain predictable, and your user experience stays silky smooth at 120 FPS.

---

### 📦 Explore the BlocSignal Ecosystem

- **Core Package:** [`bloc_signals`](https://pub.dev/packages/bloc_signals)
- **Flutter Bindings:** [`bloc_signals_flutter`](https://pub.dev/packages/bloc_signals_flutter)
- **Testing Utilities:** [`bloc_signals_test`](https://pub.dev/packages/bloc_signals_test)
- **Documentation & Interactive Showcase:** [blocsignal.dev](https://blocsignal.dev)
- **GitHub Repository:** [github.com/RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)
