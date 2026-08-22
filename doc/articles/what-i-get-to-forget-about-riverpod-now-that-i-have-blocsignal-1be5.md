---
series: "BlocSignal Architecture & Practice"
title: "What I Get to Forget About Riverpod Now That I Have BlocSignal"
description: "The greatest upgrade in developer experience isn't what you have to learn—it's the mental gymnastics you get to unlearn. A respectful, deep-dive comparison into why shedding Riverpod's cognitive overhead brings joy back to Flutter architecture."
tags: ["flutter", "dart", "riverpod", "statemanagement"]
---

## The Best Feature in Software Is What You Get to Forget

In software engineering, we usually measure framework upgrades by what they *add*: new syntax, new macros, new features, new abstractions.

But as any developer who has maintained large Flutter applications over several years knows, the most profound upgrade in developer experience isn't what new concepts you are forced to memorize—**it’s the mental gymnastics, framework-specific edge cases, and defensive rituals you finally get to forget and unlearn.**

Before we dive into technical specifics, let's establish something essential: **Rémi Rousselet is a pioneer and a brilliant engineer.** When Rémi created `provider` in Flutter's early days and later built `Riverpod` in 2020, he solved real, glaring flaws in Flutter's core `InheritedWidget` mechanics (such as conditional dependency leaks and lack of compile safety). The entire Flutter ecosystem owes Rémi immense gratitude for pushing the boundaries of Dart architecture.

For years, I was a vocal, passionate—at times almost zealous—advocate for Riverpod. In discussions, community forums, and client architectures, I routinely recommended Riverpod above classic BLoC, Provider, and almost every other state management alternative. I championed its compile-time safety and global declarative graph vision because it genuinely solved tough problems we faced in earlier Flutter eras.

However, over the course of Riverpod's evolution across v1, v2 (the code-gen era), and v3, solving every edge case within a global declarative provider graph led to a staggering accumulation of cognitive surface area. Building real-world Flutter apps with Riverpod today requires developers to maintain a complex internal rules engine just to avoid subtle runtime footguns.

And yet, recognizing how much mental gymnastics this has gradually demanded, I find myself genuinely thrilled and relieved to be pivoting. When you switch to **`BlocSignal`** (which combines the proven discipline of BLoC/Cubit with the synchronous speed and fine-grained reactivity of Signals), you realize just how much mental baggage you were carrying—and I am excited to share that journey with all of you.

### A Quick Note on Lints and IDE Assists

It is worth acknowledging that the Riverpod ecosystem has invested heavily in custom analyzer lints (`riverpod_lint`), IDE plugins, and automated quick-fixes (such as *"Wrap with ConsumerWidget"* or *"Convert to Notifier"*).

While these tooling aids are genuinely helpful, they only address surface-level syntax—they cannot eliminate the underlying cognitive load. An IDE shortcut that automatically rewrites your widget class hierarchy does not prevent a controller from disposing mid-flight during an `await` gap, nor can a linter rule save a navigation stack from wiping when a router provider re-evaluates. 

Tooling assists can bandage syntactic friction, but true architectural simplicity removes the friction at the root.

Here is the running list of everything you get to **forget**—and why your architecture gets significantly cleaner the moment you do.

---

## 1. 🗑️ Forget `build_runner` and Code-Gen Rituals

### The Riverpod Gymnastics:
In modern Riverpod (v2/v3), code generation is the officially recommended path. That means:
- Annotating classes with `@riverpod`.
- Extending obscure generated private base classes (`extends _$AuthNotifier`).
- Running `dart run build_runner watch --delete-conflicting-outputs` in a separate terminal tab, spinning laptop fans while consuming gigabytes of RAM.
- Waiting several seconds every time you rename a parameter or add a method just for IDE autocomplete to work again.
- Dealing with noisy `.g.dart` generated files cluttering Git diffs and code reviews.

*(Yes, Riverpod still technically supports manual `NotifierProvider` / `Notifier` syntax without code generation. But code-gen is the officially documented standard and recommended default throughout modern Riverpod tutorials and guides. Writing manual syntax is verbose and forfeits features like typed `.family` parameter records.)*

```dart
// 🤯 Riverpod (Code Generation Required)
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'counter.g.dart';

@riverpod
class Counter extends _$Counter {
  @override
  int build() => 0;

  void increment() => state++;
}
```

### What You Do in BlocSignal:
You write **pure Dart**. No `build_runner`. No part files. No code-gen watchers. Instant autocomplete in every IDE, 100% of the time.

```dart
// ⚡ BlocSignal (Zero Code-Gen, Pure Dart)
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}
```

---

## 2. 🗑️ Forget Widget Class Hierarchy Gymnastics & `WidgetRef` Plumbing

### The Riverpod Gymnastics:
In Riverpod, you cannot read or watch state from standard Flutter widgets without either:
1. Converting your `StatelessWidget` into a `ConsumerWidget` and changing `build(BuildContext context)` to `build(BuildContext context, WidgetRef ref)`.
2. Converting your `StatefulWidget` into a `ConsumerStatefulWidget` and `State<T>` into `ConsumerState<T>`.
3. If using Flutter Hooks, extending `HookConsumerWidget` (a Frankenstein base class).
4. Passing `WidgetRef ref` down private helper functions, widget sub-methods, and domain callbacks because `ref` is not accessible from standard `BuildContext`.

```dart
// 🤯 Riverpod
class UserProfileView extends ConsumerWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    return Text(user.name);
  }
}
```

### What You Do in BlocSignal:
You use **standard Flutter widgets**. `StatelessWidget`, `StatefulWidget`, or `HookWidget`. You interact via idiomatic `BuildContext` extensions or dedicated declarative widgets (`BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`):

```dart
// ⚡ BlocSignal
class UserProfileView extends StatelessWidget {
  const UserProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserCubit>().stateValue;
    return Text(user.name);
  }
}
```
*Zero custom base classes. Zero `WidgetRef` drilling. Native Flutter.*

---

## 3. 🗑️ Forget the Provider "Alphabet Soup" & Deprecation Whiplash

### The Riverpod Gymnastics:
Over the last few years, Riverpod developers have had to navigate an exhausting taxonomy of provider variants:
- `Provider`
- `StateProvider` *(deprecated in v2/v3)*
- `StateNotifierProvider` *(deprecated)*
- `ChangeNotifierProvider`
- `FutureProvider`
- `StreamProvider`
- `NotifierProvider`
- `AsyncNotifierProvider`
- `StreamNotifierProvider`
- `AutoDisposeProvider` / `AutoDisposeFutureProvider`
- `.family` modifiers with tuple parameter records

Each variant had its own slightly different rules for error handling, disposal, and lifecycle callbacks.

### What You Do in BlocSignal:
There are only **two intuitive, unified primitives**:
1. **`CubitSignal<State>`**: For method-based state management (call methods, compute derived state, emit new values).
2. **`BlocSignal<Event, State>`**: For formal, event-driven unidirectional data flow with explicit event hierarchies and concurrency transformers (`droppable`, `restartable`, `sequential`).

Both use standard Dart constructors, synchronous `emit()`, and expose `state` as a reactive `ReadonlySignal<State>`.

*(While Riverpod's generic `AsyncValue` is handy for basic fetch-and-display screens, real enterprise applications quickly outgrow generic 3-state wrappers and require rich domain models—such as partial validations, optimistic rollbacks, and multi-step forms. With `BlocSignal`, you leverage the full expressive power of Dart 3 sealed classes for domain state, while retaining access to `AsyncSignal` when you want declarative async futures.)*

## 4. 🗑️ Forget the "Ref World vs. Non-Ref World" Boundary

### The Riverpod Dilemma:
As I taught developers and engineering teams about Riverpod over the years, I gradually adopted a mental model of the **"Ref World" vs. the "Non-Ref World"** to help students understand a fundamental reality of Riverpod's design.

In Riverpod, reactive state is strictly confined inside a `ProviderContainer`—the "Ref World". As long as you are inside a `ConsumerWidget` or inside another provider, you hold a `Ref` or `WidgetRef`, and everything connects. But the moment you step into standard Dart code—such as HTTP client interceptors, WebSocket listeners, background database services, or routing configurations—you are stranded in the "Non-Ref World". To connect the two, you are forced to:
- Drill a `Ref ref` parameter through every layer and pollute pure Dart domain classes with framework dependencies.
- Or expose a global top-level `ProviderContainer` variable as an escape hatch.

### What You Do in BlocSignal:
`bloc_signals` is a **100% pure Dart package with zero Flutter dependencies**. 
- You can instantiate and observe a `CubitSignal` or `BlocSignal` anywhere: inside Flutter widgets, CLI tools, Jaspr web applications, or Serverpod backend services.
- Pure Dart services can read `cubit.stateValue` or subscribe directly to `cubit.state.subscribe((state) => ...)` with zero container ceremony.

**What about cross-container coordination?** In classic stream-based BLoC, coordinating two Blocs was notoriously clunky (often forcing developers to nest multiple `BlocListener` widgets in the UI tree). In `BlocSignal`, because every state is exposed as a reactive `ReadonlySignal<State>`, cross-Cubit derived state is trivial in pure Dart business logic:

```dart
// ⚡ Pure Dart Cross-Cubit Derivation (Zero UI Listeners Needed)
late final isCheckoutReady = computed(() => 
  authCubit.state().isAuthenticated && cartCubit.state().items.isNotEmpty
);
```
*Zero widget tree nesting. Zero stream subscriptions. 100% testable in pure Dart.*

---

## 5. 🗑️ Forget the `routerProvider` Navigation Stack Nuke

### The Riverpod Footgun:
Perhaps the most notorious casualty of the "Non-Ref World" boundary is routing. Because routers like `GoRouter` are standard Dart objects that live squarely in the Non-Ref World, developers frequently attempt to pull their router into the Ref World by wrapping it in a Riverpod `Provider` so it can access `ref` and observe live authentication state:

```dart
// 💣 The Innocent-Looking Riverpod Disaster
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider); // 💣 DISASTER
  return GoRouter(
    redirect: (context, state) => auth.isLoggedIn ? null : '/login',
    routes: [...],
  );
});
```

**The Runtime Bug:** Whenever `authProvider` emits (or background token refresh occurs), `ref.watch` destroys and **recreates the entire `GoRouter` instance**.
- The user's entire navigation history stack is wiped clean.
- Deeply nested tabs and modal sheets vanish instantly.
- Scroll offsets reset to the top.

To fix this in Riverpod, you cannot just write intuitive code; you must possess a deep, esoteric understanding of *both* how GoRouter manages its internal delegate and how Riverpod rebuilds provider dependencies. The prescribed workaround is constructing a custom `ChangeNotifier` bridge with `ref.listen` to feed `refreshListenable`.

Worse still, when this bug strikes in production, there are no error logs or stack traces—just an unexplained navigation reset. Developers are often left struggling with a complete lack of information and traceability, unclear even where to place debugger probes or log statements to catch why the router is vanishing.

### What You Do in BlocSignal:
Your `GoRouter` instance is created once and remains permanent. You connect it directly using `toListenable()`:

```dart
// ⚡ BlocSignal: Stable Router, Live Redirects
final router = GoRouter(
  refreshListenable: authCubit.toListenable(),
  redirect: (context, state) => authCubit.stateValue.isLoggedIn ? null : '/login',
  routes: [...],
);
```
*Zero router destruction. Unbroken navigation stacks. 100% deterministic.*

---

## 6. 🗑️ Forget the "Self-Disposing Async Mutation" Crash

### The Riverpod Footgun:
In Riverpod 3.0, auto-disposal is enabled by default. While the intended goal of automatic disposal is commendable (preventing memory leaks in long-lived trees), using **implicit UI reference counting to govern asynchronous business logic** creates severe race conditions:

```dart
// 💣 Riverpod 3.0 Trap
@riverpod
class NoteController extends _$NoteController {
  @override
  Future<List<Note>> build() => repository.fetchNotes();

  Future<void> deleteNote(String id) async {
    state = const AsyncLoading();
    await repository.deleteNote(id);
    
    // 💥 CRASH: "Cannot use Ref after it has been disposed"
    // If the user navigates away or no widget is watching this controller during the `await`,
    // Riverpod garbage-collects this instance mid-flight!
    ref.invalidateSelf(); 
  }
}
```

To work around this in Riverpod, developers are forced into defensive gymnastics:
- **Defensive Guards:** Sprinkling `if (ref.mounted)` checks after every single asynchronous `await`.
- **Action Controller Sprawl:** Creating an entirely separate `NoteDeleteActionController` class just to execute a single async method call without auto-disposing the main list provider.
- **Keep-Alive Token Juggling:** Manually acquiring and releasing `KeepAliveLink` tokens:
  ```dart
  final link = ref.keepAlive(); // 🤯 Manual retain-count management in Dart!
  try {
    await repository.deleteNote(id);
  } finally {
    link.close(); // Remember to release the token, or leak memory forever!
  }
  ```
  Think about how absurd that is: you find yourself having to write **meta-state management just to manage the lifecycle of your state management system**. High-level declarative Dart is suddenly reduced to manual reference-count lock juggling.

### What You Do in BlocSignal:
In `BlocSignal`, state containers are **standard Dart objects with explicit, predictable ownership**. If an async method is running, it executes to completion. If a Bloc is closed, `emit()` is safely dropped with zero unhandled runtime crashes:

```dart
// ⚡ BlocSignal
class NoteCubit extends CubitSignal<NoteState> {
  NoteCubit({required this.repository}) : super(initialState: const NoteState.initial());

  final NoteRepository repository;

  Future<void> deleteNote(String id) async {
    emit(stateValue.copyWith(isLoading: true));
    await repository.deleteNote(id);
    final notes = await repository.fetchNotes();
    emit(stateValue.copyWith(isLoading: false, notes: notes));
  }
}
```

---

## 7. 🗑️ Forget `.family` Parameter Isolation & Cache Silos

### The Riverpod Dilemma:
When you use Riverpod's `.family` modifier to parameterize queries:
```dart
final userPostsProvider = FutureProvider.family<List<Post>, String>((ref, userId) => ...);
final postDetailProvider = FutureProvider.family<Post, String>((ref, postId) => ...);
```
Each parameter generates an isolated provider instance. If the user likes a post in `postDetailProvider('post-123')`, `userPostsProvider('user-456')` still contains the old, unliked copy of that post in memory. You now have to build complex cache invalidation bridges across multiple isolated providers.

### What You Do in BlocSignal:
You use normal Dart parameters in constructors (`PostCubit(userId: id)`) and share live reactive signal stores (like `mapSignal` or `computed()`) across containers. When a post is updated in the central signal store, every widget and cubit observing it updates **synchronously in the exact same frame**.

---

## 8. 🗑️ Forget the `ref.watch` in Callbacks Infinite Loop Trap

### The Riverpod Gotcha:
One of the most common mistakes for Flutter developers learning Riverpod is calling `ref.watch` inside an `onPressed` or gesture callback instead of `ref.read`:

```dart
// 💣 Riverpod Bug
ElevatedButton(
  onPressed: () {
    // 💥 Calling watch inside an event handler registers an invalid dependency
    // or creates unexpected rebuild cascades!
    ref.watch(authProvider.notifier).login();
  },
  child: const Text('Login'),
)
```

### What You Do in BlocSignal:
The distinction in `BlocSignal` is natural and enforced by Flutter's existing `BuildContext` idioms:
- In callbacks/handlers: `context.read<AuthCubit>().login()` (O(1) lookup, zero subscription).
- In UI builders: `context.watch<AuthCubit>().stateValue` or `BlocSignalBuilder<AuthCubit, AuthState>` (explicit reactive rebuild boundary).

---

## 9. 🗑️ Forget In-Place Mutation Silent Drop Traps

### The Riverpod Footgun:
In Riverpod 3, notifying listeners relies strictly on reference equality (`identical(oldState, newState)`). If you mutate a list in-place:

```dart
// 💣 Riverpod 3 Silent Failure
state.add(newItem);
state = state; // ❌ Does NOT trigger UI rebuilds because identical(state, state) is true!
```

### What You Do in BlocSignal:
`BlocSignal` provides explicit, customizable equality checks via `SignalOptions(equals: ...)` or standard value equality (using Dart 3 records, Freezed, or `fast_immutable_collections`). When you call `emit(newState)`, the transition is explicit, logged through `BlocSignalObserver`, and propagated synchronously.

---

## 10. 🗑️ Forget Subtree `ProviderScope(overrides: [...])` Scoping & Modal Traps

### The Riverpod Gymnastics:
In Riverpod, when you need to scope data down a specific widget subtree—such as passing item data down a list view or customizing a controller for a nested section—Riverpod prescribes nesting a `ProviderScope` with `overrides:`:

```dart
// 🤯 Riverpod: Scoping data in a list
ListView.builder(
  itemCount: todos.length,
  itemBuilder: (context, index) {
    return ProviderScope(
      overrides: [
        currentTodoProvider.overrideWithValue(todos[index]),
      ],
      child: const TodoItemTile(),
    );
  },
);
```

This pattern introduces several subtle, high-friction pitfalls:
1. **Container Overhead in Lists:** Wrapping 100 list tiles in `ProviderScope` instantiates 100 nested `Element` widgets and separate internal provider container nodes.
2. **The "Split-Brain" Dependency Trap:** If Provider B depends on Provider A, and you override A in a nested `ProviderScope` without *also* explicitly overriding B, Provider B still resolves against the **root** un-overridden A, causing baffling data desynchronization bugs.
3. **The Modal & Dialog Disconnection Bug:** When you call `showDialog()` or `showModalBottomSheet()`, Flutter pushes the new route to the root `Navigator` overlay. Because the dialog is mounted outside the local subtree's `ProviderScope`, all local overrides are instantly lost—causing the modal to either crash with missing providers or silently read outdated root state.

### What You Do in BlocSignal:
You use **standard Dart and Flutter idioms**:
- In lists: Pass data directly via constructor parameters (`TodoItemTile(todo: todos[index])`).
- In subtrees: Use standard Flutter scoping with `BlocSignalProvider.value(value: todoCubit, child: ...)` or provide scoped instances cleanly.
- In dialogs: Pass the Cubit directly to `BlocSignalProvider.value` in the dialog builder, or let it resolve naturally up the Flutter element tree.

---

## 11. 🗑️ Forget Complex `ProviderContainer` Mocking & Test Rigmarole

### The Riverpod Testing Ceremony:
In Riverpod, unit tests and widget tests require assembling a `ProviderContainer` or wrapping test widgets in `ProviderScope(overrides: [...])`:

```dart
// 🤯 Riverpod Test Ceremony
final container = ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(mockAuthRepo),
    apiClientProvider.overrideWithValue(mockApiClient),
    // ⚠️ Miss just one transitive provider in this list, and your test
    // will accidentally make real network calls or throw late-init errors!
  ],
);
addTearDown(container.dispose);
```

### What You Do in BlocSignal:
State containers are plain Dart classes with **direct constructor injection**. You instantiate your Cubit or Bloc with your mock repository directly:

```dart
// ⚡ BlocSignal: Declarative, Instant Unit Testing
blocSignalTest<CounterCubit, int>(
  'emits [1] when increment is called',
  build: () => CounterCubit(repository: mockRepository),
  act: (cubit) => cubit.increment(),
  expect: () => [1],
);
```
Because `BlocSignal` state transitions are **synchronous**, assertions execute immediately without flaky `tester.pumpAndSettle()` timeouts or async race conditions.

---

## 12. 🤖 Forget the AI & LLM Hallucination Nightmare

### The Riverpod AI Friction:
If you pair-program with AI coding assistants—whether Claude, Cursor, GitHub Copilot, ChatGPT, or Gemini—you have likely experienced how difficult Riverpod is for modern LLMs:

1. **The Version Multi-Verse:** LLM training data contains years of conflicting Riverpod eras (v0.14 `ChangeNotifierProvider`, v1.0 `StateNotifierProvider`, v2.0 `@riverpod` code-gen, and v3.0 `Notifier`). AI models constantly mix up these eras, hallucinating deprecated APIs, invalid provider types, or incompatible syntax.
2. **Code-Gen Blindness:** LLMs cannot see generated code before `build_runner` executes. When an AI generates a `@riverpod` class, it frequently botches the synthesized `_$ClassName` inheritance, misnames the generated provider, or forgets the `part 'file.g.dart';` declaration.
3. **`Ref` Scope Confusion:** AI models frequently lose track of the "Ref World" boundary—attempting to access `ref` inside widget constructors, passing `WidgetRef` into deep business logic layers, or failing to convert widgets to `ConsumerStatefulWidget`.
4. **Implicit Auto-Disposal Bugs:** LLMs routinely write async mutation methods inside auto-disposing notifiers without accounting for `ref.mounted` guards or keep-alive tokens, generating code that looks plausible but crashes in production.

### What You Do in BlocSignal:
LLMs excel at **pure, standard Dart with explicit contracts**:
- **Standard Dart & Predictable Conventions:** Pure classes, direct constructor injection, and idiomatic Flutter `BuildContext` lookups. There is no code-gen magic for the LLM to guess.
- **Zero `build_runner` Feedback Loops:** AI agents can write features, scaffold tests, and immediately verify analyzer diagnostics without waiting for external code generation steps.
- **Vast Training Ground:** BLoC and Cubit are among the most consistently documented and deeply represented architectural patterns in AI training datasets. LLMs generate accurate, idiomatic `BlocSignal` code on the first try.
- **Deterministic AI-Generated Tests:** AI tools generate rock-solid, synchronous `blocSignalTest` suites without getting tripped up by `ProviderContainer` setup boilerplate or async frame timing issues.
- **First-Class AI Skills From Day One:** Rather than leaving LLMs to guess architectural boundaries, `BlocSignal` ships from day one with installable agent skills covering migrations, interop adapters, and production best practices.

---

## Summary: The Cognitive Weight You Leave Behind

| What You Leave Behind in Riverpod | What You Enjoy in BlocSignal |
| :--- | :--- |
| **`build_runner` & `.g.dart` Code Generation** | **Pure, standard Dart with instant IDE autocomplete** |
| **`ConsumerWidget` & `WidgetRef` Plumbing** | **Standard Flutter widgets & clean `BuildContext` APIs** |
| **Alphabet Soup of 10+ Provider Types** | **2 Unified Primitives (`CubitSignal` & `BlocSignal`)** |
| **Ref vs Non-Ref Boundary Walls** | **Zero-dependency pure Dart state usable anywhere** |
| **`GoRouter` Navigation Stack Wipes** | **Stable router instance with `.toListenable()`** |
| **"Self-Disposing" Async Mutation Crashes** | **Predictable, developer-owned object lifecycles** |
| **Isolated `.family` Cache Silos** | **Direct constructor injection & normalized Signals graph** |
| **`ref.watch` in Callbacks Rebuild Cascades** | **Clean separation of `context.read()` & `context.watch()`** |
| **In-Place Mutation Silent Drops** | **Explicit transitions via `emit()` with custom equality** |
| **Subtree `ProviderScope(overrides:)` & Modal Disconnects** | **Standard Dart props & native `InheritedWidget` scoping** |
| **Complex `ProviderContainer` Test Overrides** | **Direct constructor mocking & declarative `blocSignalTest`** |
| **AI / LLM Version Hallucinations & Code-Gen Errors** | **First-shot AI accuracy with standard Dart & BLoC patterns** |

---

## 🌉 Currently Mired in Riverpod? You Don’t Need a Big-Bang Rewrite

If you maintain a large production codebase built on Riverpod, you might be thinking: *"This sounds wonderful, but our entire team is already knee-deep in Riverpod. We cannot afford to halt feature delivery for a massive rewrite."*

You don't have to.

Through **`bloc_signals_riverpod`**, you get a seamless, **bidirectional interop bridge** that allows you to adopt `BlocSignal` incrementally, one feature or screen at a time.

### Direction 1: Expose a BlocSignal to Existing Riverpod Widgets
If you build a new feature using a clean, pure Dart `CubitSignal`, you can expose it directly to existing Riverpod widgets as a standard `NotifierProvider` using `.toProvider()`:

```dart
// 1. Build your new feature with a pure Dart Cubit
final cartCubit = CartCubit();

// 2. Adapt it into a Riverpod provider with a single call
final cartProvider = cartCubit.toProvider();

// 3. Existing Riverpod ConsumerWidgets watch it seamlessly:
class CartBadge extends ConsumerWidget {
  const CartBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    return Badge(label: Text('${cartState.itemCount}'));
  }
}
```

### Direction 2: Consume Legacy Riverpod Providers in BlocSignal
Conversely, if your new BlocSignal architecture needs to read data from legacy Riverpod providers that you aren't ready to rewrite yet, you can adapt any `ProviderListenable` with `.toBlocSignal(ref)`:

```dart
// Adapt any legacy Riverpod provider into a reactive BlocSignal
final userBloc = legacyUserProvider.toBlocSignal(ref);

// Read stateValue synchronously or subscribe to state changes
print(userBloc.stateValue.userName);
```

You can migrate your application piece by piece—shedding the cognitive load on new features immediately while existing code continues running uninterrupted.

---

## Getting Started

If you want the architectural discipline of BLoC combined with the modern, zero-latency reactive power of Signals—without the code-gen or cognitive overhead—give BlocSignal a spin.

```yaml
dependencies:
  bloc_signals: ^1.0.0
  bloc_signals_flutter: ^1.0.0

  # Optional for incremental migration:
  bloc_signals_riverpod: ^1.0.0
```

Learn more at [**blocsignal.dev**](https://blocsignal.dev) or explore the source on [**GitHub**](https://github.com/RandalSchwartz/BlocSignal).
