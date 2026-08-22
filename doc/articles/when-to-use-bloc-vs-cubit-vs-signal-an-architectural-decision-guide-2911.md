---
series: "BlocSignal Architecture & Practice"
title: "When to Use Bloc vs. Cubit vs. Signal: An Architectural Decision Guide"
published: true
description: "Stop guessing how to structure your Flutter state. Here is a definitive, 4-tier decision rubric comparing raw Signals, CubitSignal, BlocSignal, and persistence mixins."
tags: "flutter, dart, architecture, webdev"
---

## The Flutter State Dilemma

Every Flutter developer eventually wrestles with state management granularity:

> *"How do I balance developer ergonomics against architectural rigor? When is a simple reactive primitive sufficient, and when do I truly need a structured, event-driven state container?"*

For years, developers have swung between two frustrating extremes:
1. **The Over-Engineering Trap**: Creating multiple event classes, sealed hierarchies, and asynchronous stream plumbing just to toggle a boolean accordion or expand a card.
2. **The Spaghetti Trap**: Relying entirely on untracked, ad-hoc mutable state for complex transactional workflows, leading to race conditions, untraceable mutations, and hard-to-test side effects.

With **[BlocSignal](https://blocsignal.dev)**—which bridges Felix Angelov's BLoC architectural rigor with Rody Davis's Preact Signals v7 engine—we have a unified spectrum. State updates propagate **synchronously in 0ms**, eliminating microtask queue delays while preserving strict architectural boundaries.

Here is the definitive rubric for picking the exact right container for your state.

---

## The 4-Tier State Hierarchy

Rather than forcing every piece of state into the same mold, view your application as a 4-tier hierarchy:

```plaintext
[Raw Signal / computed()]        --> Local widget micro-state & derived calculations
       │
[CubitSignal<State>]             --> Feature domain logic & CRUD with direct method calls
       │
[BlocSignal<Event, State>]       --> Mission-critical pipelines with reified event concurrency
       │
[HydratedMixin / ReplayMixin]    --> Synchronous persistence (Frame 1) & Undo/Redo history
```

---

## 1. Raw Signals: Widget-Local Ephemeral State

Use raw signals (such as `signal()`, `computed()`, and the `.$` extension syntax) when state is **strictly local to a single widget subtree** and requires zero backend orchestration.

### Ideal Use Cases:
* **UI Interactions**: Accordion open/close toggles, dropdown menu visibility, modal dialog triggers, and hover states.
* **Derived Computations**: Calculating an invoice total dynamically from an active item list (`computed(() => items.fold(0, (sum, i) => sum + i.price))`).
* **Direct GPU/Render Bindings**: Animation tickers, mouse positions, and custom canvas scroll offsets.

### Why It Fits:
Raw signals eliminate class boilerplate entirely. Signal graphs update reactive nodes with sub-millisecond efficiency and are automatically garbage-collected when the hosting widget unmounts.

```dart
// Pure view calculation with zero class ceremony
final isExpanded = signal(false);
final totalPrice = computed(() => cart.value.fold(0, (sum, item) => sum + item.price));
```

> **Anti-Pattern to Avoid**: Never create a full BLoC with separate event classes just to track whether a UI modal is visible.

---

## 2. CubitSignal: Feature Domain Logic & CRUD

Use `CubitSignal<State>` as your **default workhorse** for standard screen features and business domains.

### Ideal Use Cases:
* **Standard CRUD Screens**: Loading user profiles from a REST/GraphQL API, creating records, updating fields, and deleting rows.
* **Form State**: Managing form validation errors, submit button spinners, and error alerts.
* **Application Settings**: Toggling dark mode themes, changing localization languages, and updating account preferences.

### Why It Fits:
`CubitSignal` exposes direct imperative methods (such as `cubit.updateName('Alice')`), enforcing a clean, predictable unidirectional data flow. You get synchronous in-frame updates, automatic equality de-duplication (`if (stateValue == newState) return;`), and global observability (`BlocSignalObserver`) without needing separate event classes.

```dart
class ProfileCubit extends CubitSignal<ProfileState> {
  ProfileCubit() : super(initialState: const ProfileState.initial());

  Future<void> updateName(String name) async {
    emit(stateValue.copyWith(name: name, isLoading: true));
    try {
      await userRepository.saveName(name);
      emit(stateValue.copyWith(isLoading: false));
    } catch (error) {
      emit(stateValue.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }
}
```

---

## 3. BlocSignal: Event Concurrency & Audit Pipelines

Use `BlocSignal<Event, State>` when your feature requires **advanced event coordination**, **concurrency control**, or **strict enterprise audit logging**.

### Ideal Use Cases:
* **Event Concurrency Control**:
  * `restartable()`: Debounced live search inputs where new keystrokes cancel prior in-flight network queries.
  * `droppable()`: Discarding rapid duplicate button taps while a checkout payment transaction is in progress.
  * `sequential()`: Processing incoming chat messages or write operations in strict FIFO sequence.
* **Multi-Step Wizards & Funnels**: Checkout pipelines, onboarding flows, and multi-step transaction wizards.
* **OpenTelemetry & Compliance Tracing**: When every state transition must explicitly record the user action event that caused it (`onEvent` → `onTransition`).

```dart
sealed class SearchEvent {
  const SearchEvent();
}

final class QueryChanged extends SearchEvent {
  final String query;
  const QueryChanged(this.query);
}

class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
  SearchBloc(this.apiService) : super(initialState: const SearchState.idle()) {
    on<QueryChanged>(
      (event, emit) async {
        if (event.query.isEmpty) {
          emit(const SearchState.idle());
          return;
        }
        emit(const SearchState.loading());
        final results = await apiService.search(event.query);
        emit(SearchState.success(results));
      },
      transformer: restartable(), // Automatically aborts previous query on new input!
    );
  }

  final ApiService apiService;
}
```

---

## 4. Specialized Mixins: Persistence & Undo/Redo

Both `CubitSignal` and `BlocSignal` compose with specialized mixins:

* **Frame-1 Instant Persistence (`bloc_signals_hydrate`)**: Restores cached state synchronously on startup before the first frame renders, preventing loading flashes and layout shifts.
* **Undo & Redo History (`bloc_signals_replay`)**: Maintains a bounded change stack (`cubit.undo()`, `cubit.redo()`, `cubit.canUndo`) for drawing surfaces, rich text editors, and document builders.

---

## Architectural Comparison Matrix

| State Container                  | Mutation Model                       | Concurrency Control                   | Reified Events | Persistence         | Undo / Redo                     | Ideal Scope                                   |
| :------------------------------- | :----------------------------------- | :------------------------------------ | :------------- | :------------------ | :------------------------------ | :-------------------------------------------- |
| **Raw `Signal` / `computed()`**  | Direct assignment (`.value = x`)     | In-frame direct                       | No             | Manual              | Manual                          | Widget-local ephemeral UI state               |
| **`CubitSignal<State>`**         | Direct methods (`cubit.action()`)    | Mutex locks                           | No             | Via `HydratedMixin` | Via `ReplayMixin`               | Standard screen features, settings, CRUD      |
| **`BlocSignal<Event, State>`**   | Reified events (`bloc.add(Event())`) | Built-in (`droppable`, `restartable`) | Yes            | Via `HydratedMixin` | Via `ReplayMixin`               | Search inputs, multi-step wizards, audit logs |
| **`HydratedCubitSignal<State>`** | Direct methods + storage             | Mutex locks                           | No             | Frame-1 Synchronous | Via `ReplayMixin`               | Persistent user preferences, auth caching     |
| **`ReplayCubitMixin<State>`**    | Direct methods + change stack        | Mutex locks                           | No             | Via `HydratedMixin` | Built-in (`.undo()`, `.redo()`) | Drawing canvas, document editors, undo flows  |

---

## Syntax Evolution: Dart 3.5 vs. Modern Dart 3.13

Notice how modern Dart 3.13 streamlines event declarations with primary constructors:

### Traditional Dart 3.5 Syntax:
```dart
sealed class CounterEvent {
  const CounterEvent();
}

final class IncrementRequested extends CounterEvent {
  const IncrementRequested();
}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementRequested>((event, emit) => emit(stateValue + 1));
  }
}
```

### Modern Dart 3.13 Syntax:
```dart
// Single-line sealed primary constructor hierarchy
sealed class const CounterEvent();
final class const IncrementRequested() extends CounterEvent;

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementRequested>((event, emit) => emit(stateValue + 1));
  }
}
```

---

## Try the Interactive Decision Wizard

Want to find the ideal state container for your specific feature?

👉 **[Try the Interactive State Selector on blocsignal.dev](https://blocsignal.dev/#/docs/decision-matrix)**

Select your requirements (concurrency, persistence, undo/redo, scope) and get an instant recommendation with runnable starter code.

### AI Coding Assistant Support
If you use **Claude Code**, **Antigravity**, or **Cursor**, BlocSignal includes a pre-packaged AI Agent Skill bundle (`bloc-signals`) containing these exact architectural rules and validation patterns. Check out the [BlocSignal GitHub Repository](https://github.com/RandalSchwartz/BlocSignal) to explore the 10 modular packages and 25+ runnable examples!
