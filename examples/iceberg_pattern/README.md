# The Iceberg Pattern (`BlocSignal`)

A reference implementation demonstrating **The Iceberg Pattern**: a 4-tier reactive architecture that moves beyond classic Uncle Bob Clean Architecture for real-time datastore-backed Flutter applications with `BlocSignal`.

---

## 🏛️ The 4-Layer Architecture (Zero Pass-Throughs)

```plaintext
┌────────────────────────────────────────────────────────────────────────┐
│                      1. PRESENTATION LAYER (FLUTTER)                   │
│   • Lifecycle: Transient render passes                                 │
│   • Responsibilities: Pure synchronous projection (UI = ƒ(State))      │
│   • BlocSignalBuilder for UI rendering; BlocSignalListener for toasts  │
│   • Non-blocking banner when hasSyncError == true (Stale-While-Reval)  │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Projects State & Forwards Errors
┌───────────────────────────────────┴────────────────────────────────────┐
│                  2. APPLICATION FACADE (TaskBoardCubit)                │
│   • Lifecycle: Screen-scoped (created on push, disposed on pop)        │
│   • Responsibilities: View-specific filtering, sorting, & search       │
│   • Ephemeral interaction tracking (for example isDeletingTaskId spinner)│
│   • Error translation: Catches repository sync errors ➔ onError()      │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Observes ReadonlySignal<List<Task>>
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~│~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~ WATERLINE (SURFACE LEVEL) ~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~│~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
┌───────────────────────────────────┴────────────────────────────────────┐
│             3. DOMAIN ENGINE & CACHE (TaskRepository)                  │
│   • Lifecycle: App/Session-scoped (survives screen navigation)         │
│   • Responsibilities: Async-to-sync collapse via private signals       │
│   • Data normalization: Maps cloud DTOs to pure Dart 3 records         │
│   • Global optimistic mutation engine with automatic rollback          │
│   • Public Edge: Exposes ReadonlySignal<List<Task>> & hasSyncError     │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Live Snapshots & Background Writes
┌───────────────────────────────────┴────────────────────────────────────┐
│                    4. EXTERNAL DATASTORE (FIREBASE / CLOUD)            │
│   • Lifecycle: Remote cloud persistence & server security rules        │
│   • Raw asynchronous event streams (collection.snapshots())            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## ✨ Key Architectural Features

1. **Submerged Engine (`TaskRepository`)**:
   - Uses private signals (`_cloudStreamSignal`, `_optimisticPatches`, `_hasSyncError`) to collapse asynchronous cloud streams into a warm, synchronous reactive graph.
   - Exposes clean, read-only reactive boundaries (`ReadonlySignal<List<Task>>` and `ReadonlySignal<bool> hasSyncError`).
   - Atomically updates optimistic overrides and rollback states via `batch()`.
2. **Visible Facade (`TaskBoardCubit`)**:
   - Screen-scoped lifecycle created on route mount and disposed on route pop.
   - Computes view-specific filtered slices (`activeFilterTag`) without modifying the shared underlying repository data.
   - Tracks row-level ephemeral interaction state (`isDeletingTaskId`).
   - Translates domain exceptions into standard BLoC channels (`onError`).
3. **Pure Synchronous Presentation (`TaskBoardScreen`)**:
   - Pure synchronous widget projection (`UI = ƒ(State)`) with zero stream subscriptions and zero async builders (`FutureBuilder` / `StreamBuilder`).
   - Stale-While-Revalidate UX: Displays cached tasks with a subtle warning banner during offline or sync disruption instead of replacing content with a disruptive full-screen error widget.
4. **Dart 3 Records as Domain Models**:
   - Zero boilerplate classes; structural equality and pattern matching ready out of the box (`typedef Task = ({String id, String title, bool isCompleted, List<String> tags});`).

---

## 🚫 What Has Disappeared

- ❌ **No Anemic Use Cases**: Zero 3-line pass-through interactors doing nothing but forwarding calls to a repository.
- ❌ **No `StreamBuilder` or `FutureBuilder` Widgets**: Zero async builders in your Flutter widget tree; UI is 100% synchronous projection (`UI = ƒ(State)`).
- ❌ **No Microtask Frame Lag**: Zero waiting for asynchronous stream queues to cycle; state updates propagate synchronously in frame 0.
- ❌ **No Torn UI States**: Atomic transitions via `batch()` prevent intermediate partial states during optimistic reconciliation and rollback.
- ❌ **No Disruptive Error Flickers**: Stale-while-revalidate caching keeps data visible with a subtle banner instead of replacing the screen with a full-page error widget.
- ❌ **No Boilerplate Model Classes**: Pure Dart 3 records replace hundreds of lines of tedious `copyWith`, `props`, and code-generation ceremony.

---

## 🚀 Running the Example

```bash
cd examples/iceberg_pattern
flutter run
```

---

## 🧪 Running Tests

```bash
cd examples/iceberg_pattern
flutter test
```
