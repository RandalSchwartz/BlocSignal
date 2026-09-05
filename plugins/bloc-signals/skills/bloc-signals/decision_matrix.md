# State Modeling & Architectural Decision Matrix

This guide provides an opinionated architectural rubric for choosing the right state management container in `BlocSignal`.

---

## 🧭 The State Modeling Hierarchy

`BlocSignal` offers a tiered spectrum of state primitives designed for specific architectural scopes:

```
[Raw Signal / computed()]        --> Local widget micro-state & derived calculations
       │
[CubitSignal<State>]             --> Feature domain logic & CRUD with direct method calls
       │
[BlocSignal<Event, State>]       --> Mission-critical pipelines with reified event concurrency
       │
[HydratedMixin / ReplayMixin]    --> Synchronous persistence (Frame 1) & Undo/Redo history
```

---

## 📊 Architectural Comparison Matrix

| Container                             | Mutation Mechanism                   | Event Concurrency                     | Reified Events | Persistence         | Undo / Redo                     | Primary Use Case                                   |
| :------------------------------------ | :----------------------------------- | :------------------------------------ | :------------- | :------------------ | :------------------------------ | :------------------------------------------------- |
| **Raw `Signal` / `computed()`**       | Direct assignment (`.value = x`)     | In-frame direct                       | No             | Manual              | Manual                          | Widget-local ephemeral UI state                    |
| **`CubitSignal<State>`**              | Direct methods (`cubit.action()`)    | Mutex locks                           | No             | Via `HydratedMixin` | Via `ReplayMixin`               | Standard screen features, settings, CRUD           |
| **`BlocSignal<Event, State>`**        | Reified events (`bloc.add(Event())`) | Built-in (`droppable`, `restartable`) | Yes            | Via `HydratedMixin` | Via `ReplayMixin`               | Search inputs, multi-step wizards, audit logs      |
| **`CubitSignalMixin<State>`**         | Direct methods (`emit(newState)`)    | Mutex locks                           | No             | Via `HydratedMixin` | Via `ReplayMixin`               | Classes extending existing superclasses (for example repositories or controllers)|
| **`BlocSignalMixin<Event, State>`**   | Reified events (`add(Event())`)      | Built-in (`droppable`, `restartable`) | Yes            | Via `HydratedMixin` | Via `ReplayMixin`               | Services with existing base class & event handling |
| **`HydratedCubitSignal<State>`**      | Direct methods + storage             | Mutex locks                           | No             | Frame-1 synchronous | Via `ReplayMixin`               | Persistent user preferences, auth caching          |
| **`ReplayCubitMixin<State>`**         | Direct methods + change stack        | Mutex locks                           | No             | Via `HydratedMixin` | Built-in (`.undo()`, `.redo()`) | Drawing canvas, document editors, undo flows       |

---

## 🎯 Detailed Heuristics & Selection Rules

### 1. When to Use Raw `Signal` / `computed()`
Choose a raw `Signal` or `computed()` when the state is purely local to a single widget and requires zero domain logic:
* **Ephemeral UI Interactions**: Checkbox toggles, accordion expansion, hover state, modal visibility.
* **Derived Calculations**: Dynamically calculating an order subtotal or filtering a list based on an active search string.
* **GPU / Render Box Direct Bindings**: Animations, scroll offsets, or canvas gestures.

> **Anti-Pattern to Avoid**: Do not create a full `BlocSignal` or `CubitSignal` with state classes for a simple boolean accordion toggle.

---

### 2. When to Use `CubitSignal<State>`
Choose `CubitSignal` as the default workhorse for application feature state:
* **Screen & Feature Logic**: User profile editing, application settings, CRUD screens, dashboard metrics.
* **Direct Imperative Ergonomics**: When method calls (`cubit.updateProfile(name)`) are clear and reified event classes add ceremony without benefit.
* **Synchronous Frame-Accurate Updates**: State emits synchronously with automatic value de-duplication (`if (stateValue == newState) return;`).

---

### 3. When to Use `BlocSignal<Event, State>`
Choose `BlocSignal` when your feature requires structured event handling, concurrency coordination, or strict audit tracing:
* **Event Concurrency Transformers**:
  * `restartable()`: Debouncing search inputs where new queries cancel in-flight network requests.
  * `droppable()`: Discarding rapid duplicate button presses while an async transaction executes.
  * `sequential()`: Processing incoming events in strict FIFO sequence.
* **Multi-Step Wizards & Funnels**: Checkout funnels, onboarding flows, and multi-step transaction wizards.
* **Compliance & OpenTelemetry Auditing**: When telemetry must capture the exact user action event that caused every state transition.

---

### 4. When to Use `CubitSignalMixin` & `BlocSignalMixin` (Single Inheritance Bypass)
Choose mixins instead of extending `CubitSignal` or `BlocSignal` when your target class already inherits from an existing framework or enterprise base class:
* **Existing Superclasses**: Classes extending Flutter's `ChangeNotifier`, `TextEditingController`, `AnimationController`, or third-party enterprise classes like `BaseRepository` / `BaseService`.
* **DRY Composition**: Combines seamlessly with other mixins (`with CubitSignalMixin<State>, HydratedMixin<State>`).
* **Polymorphic Ecosystem Compatibility**: Any class using `CubitSignalMixin` satisfies `BlocSignalBase` and is immediately usable with `BlocSignalProvider`, `context.select`, and `blocSignalTest`.

---

### 5. When to Use `HydratedCubitSignal` & `ReplayCubitMixin`
* **Persistence (`bloc_signals_hydrate`)**: When state must survive application restarts without flashing an empty or loading state on Frame 1.
* **Undo / Redo (`bloc_signals_replay`)**: When users must be able to roll back actions (for example in a drawing canvas, rich text editor, or form builder).

---

## 🛠️ Side-by-Side Code Recipes

### Recipe: Counter Feature across Patterns

#### Traditional Dart 3.5 Syntax:
```dart
// 1. Raw Signal (Local Ephemeral State)
final counter = signal(0);
void increment() => counter.value++;

// 2. CubitSignal (Feature Domain Logic)
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

// 3. BlocSignal (Event-Driven Architecture)
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

#### Modern Dart 3.13 Ergonomics:
```dart
// 1. Raw Signal with .$ extension sugar
final counter = 0.$;
void increment() => counter.value++;

// 2. CubitSignal with direct method
class CounterCubit() extends CubitSignal<int> {
  this : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

// 3. BlocSignal with primary constructor events
sealed class const CounterEvent();
final class const IncrementRequested() extends CounterEvent;

class CounterBloc() extends BlocSignal<CounterEvent, int> {
  this : super(initialState: 0) {
    on<IncrementRequested>((event, emit) => emit(stateValue + 1));
  }
}
```

---

## 🧊 Real-Time Cloud Architecture: The Iceberg Pattern

When architecting real-time applications backed by cloud datastores (such as Firebase Firestore, Supabase, or live WebSockets), avoid both the **"Anemic Lasagna"** trap (endless pass-through use cases) and **Stream Spaghetti** (complex Rx combinators). Adopt **The Iceberg Pattern**:

```plaintext
┌────────────────────────────────────────────────────────┐
│             1. PRESENTATION LAYER (FLUTTER)            │
│   • Pure synchronous projection (UI = ƒ(State))        │
│   • Non-blocking stale-while-revalidate offline banner │
└───────────────────────────▲────────────────────────────┘
                            │
┌───────────────────────────┴────────────────────────────┐
│          2. APPLICATION FACADE (CubitSignal)           │
│   • Screen-scoped lifecycle (created on push/mount)    │
│   • View-specific filtering, sorting, & search         │
│   • Ephemeral interaction tracking (for example row spinners)│
│   • Error translation ➔ CubitSignal.onError()          │
└───────────────────────────▲────────────────────────────┘
                            │ Observes ReadonlySignal<T>
~~~~~~~~~~~~~~~~~~~~~~~~~~~~│~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~ WATERLINE ~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~│~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
┌───────────────────────────┴────────────────────────────┐
│      3. SUBMERGED ENGINE & CACHE (Repository)          │
│   • App/session-scoped lifecycle                       │
│   • Private reactive signals (_cloudStreamSignal)      │
│   • Global 0ms optimistic mutations with rollback      │
│   • Exposes ReadonlySignal<T> & ReadonlySignal<bool>   │
└───────────────────────────▲────────────────────────────┘
                            │ Live cloud snapshots
┌───────────────────────────┴────────────────────────────┐
│          4. EXTERNAL DATASTORE (FIREBASE / CLOUD)      │
└────────────────────────────────────────────────────────┘
```

- **Submerged Engine (Repository Layer)**: Holds private reactive signals to collapse asynchronous streams into a warm, synchronous cache. Exposes only `ReadonlySignal<T>` and `ReadonlySignal<bool> hasSyncError`. Handles 0ms optimistic updates and rolls back silently upon network failure.
- **Visible Boundary (Cubit Layer)**: Screen-scoped facade that shapes domain data for a specific screen, manages transient interaction states, and forwards sync errors to `onError`.
- **Presentation Layer**: 100% synchronous projection (`UI = ƒ(State)`) using `BlocSignalBuilder` and `BlocSignalListener`, with zero `StreamBuilder` widgets or microtask latency.


