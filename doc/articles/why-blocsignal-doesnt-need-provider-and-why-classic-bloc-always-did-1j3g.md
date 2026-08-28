---
title: Why BlocSignal Doesn't Need Provider (And Why Classic BLoC Always Did)
description: How shedding package:provider eliminates dependency hell, fixes Flutter's lingering ghost rebuild bug, and delivers fine-grained synchronous reactivity in 2026.
tags: flutter, dart, statemanagement, webdev
series: BlocSignal Architecture & Practice
---

## How shedding package:provider eliminates dependency hell, fixes Flutter's lingering ghost rebuild bug, and delivers fine-grained synchronous reactivity in 2026.

If you browse [r/FlutterDev](https://www.reddit.com/r/FlutterDev/) on any given week, you will find the exact same architectural debate playing out:

> *"Should I use BLoC or Riverpod for my next production app? BLoC has great structure and discipline, but the stream boilerplate is overwhelming. Riverpod is reactive and flexible, but the `@riverpod` code generation and constant version transitions make it feel heavyweight."*

And inevitably, someone in the comments will chime in:
> *"I just stick with plain `package:provider` because it's simple and doesn't require code-gen."*

This trilemma—**BLoC vs. Riverpod vs. Provider**—has defined Flutter state management for over six years. But behind this debate lies a little-known architectural secret that explains why Flutter state management felt so fractured in the first place:

**Classic `flutter_bloc` was secretly just `package:provider` in disguise.**

Let's look at why classic BLoC relied on `package:provider`, the hidden runtime bugs and dependency deadlocks that came with it, why Riverpod had to break away, and how **[BlocSignal](https://blocsignal.dev)** delivers the ultimate resolution: **zero provider, zero streams, and zero code generation.**

---

## 1. Look Under the Hood: Classic BLoC's Hidden Dependency

When developers think of Felix Angelov’s classic `flutter_bloc`, they think of Streams, Sinks, and unidirectional event architectures. But if you open `flutter_bloc/pubspec.yaml`, you'll find a foundational dependency:

```yaml
dependencies:
  bloc: ^8.1.4
  provider: ^6.0.5 # 👈 The hidden foundation!
```

In classic `flutter_bloc`:
* `BlocProvider<T>` is literally an extension of `package:provider`'s `InheritedProvider`.
* `MultiBlocProvider` is just a thin alias over `MultiProvider`.
* `RepositoryProvider` is literally `Provider<T>`.

### Why Did Classic BLoC Do This?
Back in 2018–2019, writing custom `InheritedWidget` plumbing in Flutter was verbose and error-prone. Rémi Rousselet’s `package:provider` was the newly crowned Google-recommended solution for dependency injection and widget tree scoping. 

Building `flutter_bloc` on top of `package:provider` allowed BLoC to focus on its stream state machine while outsourcing widget tree scoping, lazy instantiation, and disposal to Provider.

It seemed like a great shortcut. But over time, coupling BLoC to `package:provider` introduced two massive architectural headaches.

---

## 2. The Two Fatal Flaws of the Provider Foundation

```plaintext
[ Your Application ] ──► [ flutter_bloc ]
                            │
                            └──► [ package:provider ] ──► [ Transitive Version Lock ]
```

### Flaw #1: "Dependency Hell" & Version Lockouts

Because `package:provider` is one of the most widely used packages in the Flutter ecosystem, major version updates (such as migrating from `v4` to `v5` to `v6` for null safety) created widespread dependency deadlocks:

```plaintext
Because my_app depends on:
  - legacy_auth_plugin ^2.1.0 (which depends on provider ^5.0.0)
  - flutter_bloc ^8.0.0 (which depends on provider ^6.0.5)

Version solving failed:
Cannot solve dependencies because provider ^5.0.0 is incompatible with provider ^6.0.5!
```

Every Flutter developer has experienced this nightmare:
* You couldn't upgrade `flutter_bloc` because an analytics or payment SDK pinned an older `provider`.
* Teams were forced to use risky `dependency_overrides:` in `pubspec.yaml` and pray that internal breaking changes wouldn't crash production builds.
* Engineers had to fork third-party repositories just to bump a `provider` constraint.

---

### Flaw #2: The "Lingering Dependency" (Ghost Rebuild) Bug

This is the deepest, most subtle flaw in Flutter's `InheritedWidget` system—and it was the primary catalyst that drove Rémi Rousselet to abandon Provider and create Riverpod.

When an `Element` calls `context.watch<T>()` or `Provider.of<T>(context)`, Flutter registers that `Element` as a dependent of the ancestor `InheritedWidget`. 

**The fatal catch:** Flutter’s engine **never unregisters** an element from an `InheritedWidget` on subsequent builds! Dependencies are only cleared when the widget is completely unmounted.

Consider this common conditional UI pattern:

```dart
// 👴 The Classic Provider Ghost Rebuild Trap:
Widget build(BuildContext context) {
  if (isExpanded) {
    // 🚩 Registers a permanent dependency on DetailsModel
    final details = Provider.of<DetailsModel>(context);
    return FullDetailsCard(details);
  } else {
    // 👻 GHOST REBUILD: Even when collapsed, this widget STILL rebuilds 
    // on every single change to DetailsModel forever!
    return const CompactSummaryCard();
  }
}
```

Once `isExpanded` is `true` even once, Flutter permanently binds `DetailsModel` to that widget. When the card collapses, **it continues to rebuild on every `DetailsModel` emission indefinitely**, wasting CPU cycles, battery, and rendering frames on state it isn't even displaying!

---

## 3. The Riverpod Exodus: Escaping the Widget Tree

Rémi recognized that Flutter's `InheritedWidget` and `BuildContext` had fundamental limitations that could not be fixed within `package:provider`:
1. You couldn't easily read state outside the widget tree (for example, in background services or pure Dart logic).
2. The lingering dependency bug caused unavoidable ghost rebuilds on conditional branches.
3. Combining two providers required ugly nested widget hierarchies or manual proxies.

So Rémi built **Riverpod** (`ProviderContainer`), moving the entire dependency and state graph **outside** of the Flutter widget tree.

### Where Riverpod Got Complicated
While Riverpod solved the `BuildContext` coupling, it created a new set of challenges:
* **The `@riverpod` Code-Gen Dogmatism:** To avoid writing boilerplate notifiers, developers were pushed toward `build_runner` and code generation. If you didn't run a file watcher in the background, development ground to a halt.
* **Complex Internal Types:** Behind a simple provider was a labyrinth of generated classes (`AutoDisposeAsyncNotifierProviderElement`, `ProviderFamily`, `AsyncValue` edge cases).
* **Two-World Impedance:** Managing state in an external container while rendering in Flutter's `Element` tree required complex retention counters (`autoDispose`, `disposeDelay`, `cacheTime`) to guess when widgets were truly done using state.

---

## 4. The BlocSignal Resolution: Zero Provider, Zero Code-Gen

```plaintext
┌────────────────────────────────────────────────────────────────────────┐
│                              BlocSignal                                │
│                                                                        │
│   ┌────────────────────────┐              ┌────────────────────────┐   │
│   │   The Rigor of BLoC    │              │  The Speed of Signals  │   │
│   │  • Unidirectional flow │              │  • Synchronous DAG     │   │
│   │  • Explicit Events     │      ➕      │  • Dynamic Pruning     │   │
│   │  • Strict Transitions  │              │  • Zero Streams        │   │
│   │  • 100% Traceability   │              │  • Zero Code-Gen       │   │
│   └────────────────────────┘              └────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────┘
```

**[BlocSignal](https://blocsignal.dev)** resolves this historical progression by rethinking the state primitive from the ground up:

### 1. Native O(1) `InheritedWidget` (Zero Third-Party Dependencies)
In `bloc_signals_flutter`, `BlocSignalProvider` does **not** depend on `package:provider`. 
* It is built directly on Flutter's core SDK `InheritedWidget`.
* It performs instant O(1) lookups via `getElementForInheritedWidgetOfExactType` without intermediate proxy nodes or delegating elements.
* It has **zero external dependencies**—eliminating `pub get` version deadlocks permanently.

---

### 2. Dynamic Per-Frame Dependency Pruning (No Ghost Rebuilds)
Because `BlocSignal` is powered by fine-grained Signals (`signals_flutter`), dependencies are tracked **dynamically on every single evaluation frame**:

```dart
// ⚡ In BlocSignal: Zero Ghost Rebuilds!
Widget build(BuildContext context) {
  return Watch((context) {
    if (isExpanded.value) {
      // ✅ Subscribes to detailsCubit in this frame
      return FullDetailsCard(detailsCubit.state.value);
    }
    // ✅ When false, detailsCubit is AUTOMATICALLY UNWATCHED and detached!
    return const CompactSummaryCard();
  });
}
```

When `isExpanded` turns `false`, `detailsCubit` is **immediately pruned and unwatched**. If `detailsCubit` mutates while the card is collapsed, **zero rebuilds occur**. You get pristine, leak-free reactivity without code generation or external containers.

---

### 3. Synchronous State Propagation (No Stream Queue Latency)
Classic BLoC emits state over Dart asynchronous microtask Streams. Every state change yields to the event loop before reaching the screen.

In `BlocSignal`:
* Calling `emit(newState)` updates the underlying `ReadonlySignal<State>` **synchronously in the exact same frame**.
* The GPU and widget tree render the new state with zero microtask queue hops and zero 1-frame loading flickers.

---

### 4. Streamless BLoC-to-BLoC Coordination
In classic BLoC, coordinating two Blocs requires nesting `BlocListener` widgets in the UI tree or writing complex Rx stream pipelines.

In `BlocSignal`, because state is a Signal, containers can observe each other directly in pure business logic:

```dart
class CartCubit extends CubitSignal<CartState> {
  CartCubit(this.authCubit) : super(CartInitial()) {
    // Synchronously react to auth changes without UI BlocListeners:
    createEffect(() {
      if (authCubit.state.value is Unauthenticated) {
        clearCart();
      }
    });
  }

  final AuthCubit authCubit;
}
```

---

## 5. The 4-Way Code Shootout

Let's look at how the exact same Counter feature looks across all four paradigms:

### Option A: Classic `Provider` (`ChangeNotifier`)
```dart
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners(); // 🚩 Easy to forget; triggers blanket rebuilds
  }
}
```

### Option B: Classic `flutter_bloc` (Streams + `package:provider`)
```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1); // ⏳ Asynchronous stream microtask
}
```

### Option C: Riverpod 3 (Code Generation + `build_runner`)
```dart
@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++; // ⚙️ Requires running build_runner
}
```

### Option D: Modern `BlocSignal` (Pure, Synchronous Dart)

#### In Dart 3.5 (Baseline Syntax):
```dart
class CounterCubit extends CubitSignal<int> {
  CounterCubit([int initial = 0]) : super(initialState: initial);
  void increment() => emit(stateValue + 1); // ⚡ Synchronous, zero code-gen
}
```

#### In Dart 3.13 (Modern Primary Constructor):
```dart
class CounterCubit([int initial = 0]) extends CubitSignal<int> {
  this : super(initialState: initial);
  void increment() => emit(stateValue + 1);
}
```

---

## 6. The Ultimate Comparison Matrix

| Feature | `package:provider` | Classic `flutter_bloc` | `Riverpod` 3 | `BlocSignal` |
| :--- | :---: | :---: | :---: | :---: |
| **Core Reactive Engine** | `ChangeNotifier` | Asynchronous `Stream` | External DAG | **Synchronous `Signal` DAG** |
| **Depends on `provider`?** | N/A | **YES** (`^6.0.0`) | No | **NO (Pure SDK)** |
| **Requires Code-Gen?** | No | No | **YES** (`@riverpod`) | **ZERO Code-Gen** |
| **Ghost Rebuild Fix?** | ❌ (Leaks on branch) | ❌ (Inherited leak) | ✅ (External Graph) | **✅ (Dynamic Graph Pruning)** |
| **State Immutability** | ❌ (Mutable fields) | ✅ (Immutable State) | ✅ (Immutable State) | **✅ (`ReadonlySignal`)** |
| **Execution Timing** | Synchronous | Asynchronous microtask | Synchronous | **Synchronous (Same Frame)** |
| **OpenTelemetry & Observers** | ❌ | ✅ (`BlocObserver`) | Partial (`ProviderObserver`) | **✅ (Otel + Observers)** |
| **Cross-Container Sync** | Clunky Proxies | Nested UI Listeners | `ref.watch()` | **`createEffect` / `computed`** |

---

## 7. The 60-Second Refactor: Your AI Migration Playbook

Five years ago, migrating a production app away from classic BLoC or Provider was a multi-month engineering slog. 

In **2026**, with modern AI coding assistants (Antigravity, Cursor, Copilot, Gemini) and `BlocSignal`, the refactor is practically instantaneous:

```plaintext
PROMPT FOR YOUR AI ASSISTANT:
"Replace `flutter_bloc` with `bloc_signals_flutter`.
Replace `BlocProvider` with `BlocSignalProvider`.
Replace `BlocBuilder` with `BlocSignalBuilder`.
Remove `provider` from `pubspec.yaml` and run `flutter pub get`."
```

> 💡 **Automated AI Migration Skills:** The [BlocSignal repository](https://github.com/RandalSchwartz/BlocSignal) even includes pre-packaged **AI Agent Skills & Plugins** (under `plugins/bloc-signals/skills/bloc-signals/`) for Antigravity, Cursor, Gemini CLI, and Claude Code. You can install the skill into your workspace to give your AI agent deep, rule-enforced expertise in migrating classic BLoC and Riverpod apps to BlocSignal with full test verification!

In 60 seconds:
1. All your Blocs and Cubits keep their exact same event and state models.
2. The asynchronous stream microtask delay disappears.
3. `package:provider` is wiped from your `pubspec.yaml` forever.
4. Your unit tests run synchronously with zero `pumpAndSettle()` microtask draining hacks.

---

## 8. Summary: Less is More

Software architecture advances not by adding more layers of abstraction, but by removing the friction between your code and the metal.

By removing `package:provider` and replacing stream plumbing with fine-grained Signals:
* You eliminate **version collisions and dependency solver deadlocks**.
* You fix Flutter’s **lingering dependency ghost rebuild bug**.
* You get **synchronous, same-frame UI rendering**.
* You preserve **100% of BLoC’s enterprise structure and event traceability**.

It's everything you loved about BLoC, everything you wanted from Riverpod, and all the simplicity of Provider—with none of the baggage.

---

### 🚀 Get Started with BlocSignal

* 🌐 **Official Website & Interactive Showcase:** [blocsignal.dev](https://blocsignal.dev)
* 📦 **Core Pure-Dart Package:** [`bloc_signals` on pub.dev](https://pub.dev/packages/bloc_signals)
* 📱 **Flutter UI Package:** [`bloc_signals_flutter` on pub.dev](https://pub.dev/packages/bloc_signals_flutter)
* 🌊 **Riverpod Interop Bridge:** [`bloc_signals_riverpod` on pub.dev](https://pub.dev/packages/bloc_signals_riverpod)
* 💻 **Open Source Monorepo:** [GitHub (RandalSchwartz/BlocSignal)](https://github.com/RandalSchwartz/BlocSignal)
