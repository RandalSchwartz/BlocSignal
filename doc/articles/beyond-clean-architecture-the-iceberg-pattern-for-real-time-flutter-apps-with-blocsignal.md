---
series: "BlocSignal Architecture & Practice"
title: "Beyond Clean Architecture: The Iceberg Pattern for Real-Time Flutter Apps with BlocSignal"
description: "Discover why Uncle Bob's Clean Architecture breaks down in real-time cloud apps, and learn how the Iceberg Pattern pairs synchronous signals with screen facades for 0ms optimistic UI."
published: true
tags: flutter, dart, architecture, statemanagement
---

## Why Traditional Clean Architecture Stalls in Real-Time Cloud Apps

Most enterprise Flutter tutorials preach Uncle Bob's Clean Architecture or classic BLoC layering. They show neat diagrams with concentric circles: Presentation, Use Cases / Interactors, Repositories, and Data Sources.

Yet nearly every one of those tutorials demonstrates the architecture exclusively with static REST request-response endpoints or trivial counter apps.

The moment you build a modern, datastore-backed application—powered by Firebase Cloud Firestore, Supabase, or real-time WebSockets—traditional Clean Architecture rapidly deteriorates into one of two anti-patterns:

1. **The "Anemic Lasagna" Trap**: Layers of pass-through classes (`Controller.get()` ➔ `UseCase.execute()` ➔ `Repository.fetch()` ➔ `DataSource.get()`) that merely forward method invocations to the layer below without transforming data, encapsulating invariants, or providing architectural protection. You end up writing 4 files, 3 interfaces, and 20 lines of ceremonial glue for a single read operation.
2. **Stream & Microtask Spaghetti**: Trying to synchronize multiple live cloud streams (`collection.snapshots()`, `authStateChanges()`, local search text inputs) using intricate Rx pipelines (`combineLatest3`, `switchMap`), nested subscriptions, manual lifecycle cancellations, and race-condition-prone state flags.

```plaintext
Classical "Clean" REST Layering (Anemic Lasagna):
UI ➔ Interactor ➔ Repository ➔ DataSource ➔ REST API (Pull-only, High Ceremony)

Real-Time Cloud Reality:
Firebase / Supabase ➔ Live Stream ➔ ??? ➔ Flutter UI (Push-heavy, Async Glitches)
```

**The Iceberg Pattern** solves this dilemma. By establishing a collaborative boundary between fine-grained reactive signals and unidirectional BLoC facades, the Iceberg Pattern gives real-time Flutter apps:
- Submerged, warm data caching that outlives transient screen navigations
- 0ms frame-perfect optimistic mutations with automatic server reconciliation and rollback
- Screen-scoped facades with zero pass-through ceremony
- 100% synchronous UI rendering with zero `StreamBuilder` or `FutureBuilder` latency

---

## 🏛️ The 4-Layer Architecture (Zero Pass-Throughs)

In the Iceberg Pattern, every layer has a distinct lifecycle, operates on different data structures, and addresses an indispensable, non-overlapping responsibility:

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
│   • Ephemeral interaction tracking (for example isDeletingTaskId)      │
│   • Error translation: Catches repository sync errors ➔ onError()      │
└───────────────────────────────────▲────────────────────────────────────┘
                                    │ Observes ReadonlySignal<List<Task>>
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

Notice the waterline:
- **Above the waterline (Visible)**: Flutter presentation widgets and the screen-scoped `TaskBoardCubit`. They only know about synchronous state snapshots and user intents.
- **Below the waterline (Submerged)**: The `TaskRepository` engine. It absorbs asynchronous cloud streams, collapses them into fine-grained reactive signals, coordinates optimistic mutations, and handles silent rollback upon network rejection.

---

## 📋 Locked-In Architectural Decisions

| Decision Area | Architectural Choice | Rationale & Impact |
| :--- | :--- | :--- |
| **Engine Scope** | **Repository-Scoped** | The repository owns the live datastore stream and in-memory cache. Data remains warm and active across route pushes and pops without redundant network queries. |
| **Domain Model** | **Dart 3 Records** | `typedef Task = ({String id, String title, bool isCompleted, List<String> tags});`<br>Zero class ceremony, structural equality out of the box, pattern matching ready. |
| **Optimistic Scope** | **Repository-Level** | Multi-screen consistency: toggling a task on a detail view is reflected synchronously on summary dashboards and widgets in frame 0. |
| **Repo Boundary** | **ReadonlySignal** | The repository keeps writable signals strictly private (`_`), exposing only `ReadonlySignal<List<Task>>` and `ReadonlySignal<bool>` to consumers. |
| **Mutation Strategies** | **Dual-Track** | **Optimistic**: 0ms local mutation + background write + rollback on failure.<br>**Pessimistic**: Screen tracks `isDeletingTaskId` spinner while awaiting cloud deletion confirmation. |
| **Rollback UX** | **Silent Snapback + Toast** | State silently snaps back to server truth; failure notifications route via `CubitSignal.onError` to a SnackBar. Domain models stay pure. |
| **Cloud Resilience** | **Stale-While-Revalidate** | Never replace user data with a red error box on transient disconnects. Keep cached data visible with a non-blocking warning banner. |
| **Platform Target** | **Pure Dart First** | Models, Repository, and Cubit are pure Dart—runnable on CLI, Jaspr web, server backend, or Flutter. Tested via `blocSignalTest`. |

---

## 🛠️ The Reference Implementation

Let us walk through each component of the architecture using the official reference implementation from [`examples/iceberg_pattern`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/iceberg_pattern).

### 1. The Domain Model: Zero-Ceremony Dart 3 Records

Instead of writing 60 lines of boilerplate with `copyWith`, `props`, and constructor overrides, we model domain entities as lightweight, immutable Dart 3 records:

```dart
// domain/task.dart
typedef Task = ({
  String id,
  String title,
  bool isCompleted,
  List<String> tags,
});
```

Dart 3 records provide built-in structural equality, clean destructuring, and pattern matching without any code generation or external runtime dependencies.

### 2. The Submerged Engine: `TaskRepository`

The repository is the heart of the Iceberg Pattern. It:
1. Absorbs the raw cloud snapshot stream into a private `StreamSignal`.
2. Maintains private optimistic overrides (`_optimisticPatches`).
3. Computes the combined view of server truth and pending local mutations via `computed()`.
4. Atomically reconciles or rolls back mutations using `batch()`.

```dart
// data/task_repository.dart
import 'dart:async';
import 'package:signals_core/signals_core.dart';
import 'package:iceberg_pattern_example/domain/task.dart';

class SyncRollbackException implements Exception {
  SyncRollbackException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncRollbackException: $message';
}

class TaskRepository {
  TaskRepository({
    required Stream<List<Task>> cloudSnapshotStream,
    required Future<void> Function(String id, bool isCompleted) updateCloudTask,
    required Future<void> Function(String id) deleteCloudTask,
    List<Task> initialTasks = const [],
  })  : _updateCloudTask = updateCloudTask,
        _deleteCloudTask = deleteCloudTask {
    _initEngine(cloudSnapshotStream, initialTasks);
  }

  final Future<void> Function(String id, bool isCompleted) _updateCloudTask;
  final Future<void> Function(String id) _deleteCloudTask;

  // Private Reactive Graph
  late final StreamSignal<List<Task>> _cloudStreamSignal;
  final _optimisticPatches = signal<Map<String, bool>>({});
  final _hasSyncError = signal(false);
  late final Computed<List<Task>> _computedTasks;

  void _initEngine(
    Stream<List<Task>> cloudSnapshotStream,
    List<Task> initialTasks,
  ) {
    _cloudStreamSignal = streamSignal(
      () => cloudSnapshotStream,
      options: AsyncSignalOptions<List<Task>>(initialValue: initialTasks),
    );

    _computedTasks = computed(() {
      final baseTasks = _cloudStreamSignal.value.value ?? const [];
      final overrides = _optimisticPatches.value;
      if (overrides.isEmpty) return baseTasks;

      return baseTasks.map((task) {
        final override = overrides[task.id];
        return override != null
            ? (
                id: task.id,
                title: task.title,
                isCompleted: override,
                tags: task.tags,
              )
            : task;
      }).toList();
    });
  }

  // Public Read-Only Boundaries
  ReadonlySignal<List<Task>> get tasks => _computedTasks;
  ReadonlySignal<bool> get hasSyncError => _hasSyncError;

  /// OPTIMISTIC MUTATION: Updates state across all screens in 0ms,
  /// then synchronizes with the cloud in the background.
  Future<void> toggleTask(String id, bool currentStatus) async {
    final newStatus = !currentStatus;
    _optimisticPatches.value = {..._optimisticPatches.value, id: newStatus};

    try {
      await _updateCloudTask(id, newStatus);
      // Reconcile: clear override once the cloud confirms
      batch(() {
        _hasSyncError.value = false;
        final updated = Map<String, bool>.from(_optimisticPatches.value)
          ..remove(id);
        _optimisticPatches.value = updated;
      });
    } catch (error, stackTrace) {
      // Rollback: silently remove patch and notify caller
      batch(() {
        final updated = Map<String, bool>.from(_optimisticPatches.value)
          ..remove(id);
        _optimisticPatches.value = updated;
        _hasSyncError.value = true;
      });
      Error.throwWithStackTrace(
        SyncRollbackException('Failed to update task $id. Reverted.', error),
        stackTrace,
      );
    }
  }

  /// PESSIMISTIC MUTATION: Awaits server confirmation before resolving.
  Future<void> deleteTask(String id) async {
    await _deleteCloudTask(id);
  }

  void dispose() {
    _cloudStreamSignal.dispose();
    _optimisticPatches.dispose();
    _hasSyncError.dispose();
    _computedTasks.dispose();
  }
}
```

### 3. The Visible Boundary: `TaskBoardCubit`

The application facade is screen-scoped. When a screen mounts, it creates a `TaskBoardCubit`. When the screen is popped, the Cubit is closed and its effects are disposed.

The Cubit:
- Filters or sorts tasks specifically for this view without mutating the repository.
- Tracks ephemeral UI state (for example which row is currently displaying a deletion spinner).
- Translates repository exceptions into BLoC's standard `onError` pipeline.

```dart
// application/task_board_cubit.dart
import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:iceberg_pattern_example/data/task_repository.dart';
import 'package:iceberg_pattern_example/domain/task.dart';

typedef TaskBoardState = ({
  List<Task> tasks,
  String? activeFilterTag,
  String? isDeletingTaskId,
  bool hasSyncError,
});

class TaskBoardCubit extends CubitSignal<TaskBoardState> {
  TaskBoardCubit({required TaskRepository repository})
      : _repository = repository,
        super(
          initialState: (
            tasks: repository.tasks.value,
            activeFilterTag: null,
            isDeletingTaskId: null,
            hasSyncError: repository.hasSyncError.value,
          ),
        ) {
    _initFacade();
  }

  final TaskRepository _repository;
  final _activeFilterTag = signal<String?>(null);
  final _isDeletingTaskId = signal<String?>(null);
  late final void Function() _disposeEffect;

  void _initFacade() {
    final computedState = computed(() {
      final allTasks = _repository.tasks.value;
      final filter = _activeFilterTag.value;

      final filteredTasks = filter == null
          ? allTasks
          : allTasks.where((t) => t.tags.contains(filter)).toList();

      return (
        tasks: filteredTasks,
        activeFilterTag: filter,
        isDeletingTaskId: _isDeletingTaskId.value,
        hasSyncError: _repository.hasSyncError.value,
      );
    });

    _disposeEffect = computedState.subscribe(emit);
  }

  void setFilterTag(String? tag) => _activeFilterTag.value = tag;

  /// Dispatches optimistic toggle; forwards failure to onError for SnackBar display.
  void toggleTask(String id, bool currentStatus) {
    unawaited(
      _repository.toggleTask(id, currentStatus).catchError(
        (Object error, StackTrace st) {
          onError(error, st);
        },
      ),
    );
  }

  /// Dispatches pessimistic delete; tracks row-level spinner in screen state.
  Future<void> deleteTask(String id) async {
    _isDeletingTaskId.value = id;
    try {
      await _repository.deleteTask(id);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
    } finally {
      _isDeletingTaskId.value = null;
    }
  }

  @override
  Future<void> close() async {
    _disposeEffect();
    _activeFilterTag.dispose();
    _isDeletingTaskId.dispose();
    await super.close();
  }
}
```

### 4. Pure Synchronous Presentation Binding

In Flutter, the presentation layer becomes a direct synchronous projection of state: `UI = ƒ(State)`. There are no `StreamBuilder` widgets, no connection state checks, and no microtask latency:

```dart
// presentation/task_board_screen.dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:iceberg_pattern_example/application/task_board_cubit.dart';

class TaskBoardScreen extends StatelessWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<TaskBoardCubit, TaskBoardState>(
      listenWhen: (previous, current) =>
          !previous.hasSyncError && current.hasSyncError,
      listener: (context, state) {
        if (state.hasSyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync failed: Reverted to server truth.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: BlocSignalBuilder<TaskBoardCubit, TaskBoardState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tasks (The Iceberg Pattern)'),
              bottom: state.hasSyncError
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(28),
                      child: ColoredBox(
                        color: Colors.amber,
                        child: Center(
                          child: Text(
                            'Offline / Sync Error — Showing Cached Tasks',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            body: Column(
              children: [
                // Category Filter Chips
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: state.activeFilterTag == null,
                        onSelected: (_) =>
                            context.read<TaskBoardCubit>().setFilterTag(null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Work'),
                        selected: state.activeFilterTag == 'work',
                        onSelected: (_) =>
                            context.read<TaskBoardCubit>().setFilterTag('work'),
                      ),
                    ],
                  ),
                ),
                // Task List
                Expanded(
                  child: ListView.builder(
                    itemCount: state.tasks.length,
                    itemBuilder: (context, index) {
                      final task = state.tasks[index];
                      final isDeleting = state.isDeletingTaskId == task.id;

                      return ListTile(
                        leading: Checkbox(
                          value: task.isCompleted,
                          onChanged: isDeleting
                              ? null
                              : (_) => context
                                  .read<TaskBoardCubit>()
                                  .toggleTask(task.id, task.isCompleted),
                        ),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: isDeleting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => context
                                    .read<TaskBoardCubit>()
                                    .deleteTask(task.id),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

## 🧪 Declarative Unit Testing with `blocSignalTest`

Because Models, Repository, and Cubit are pure Dart, you can verify every aspect of this architecture without spinning up a Flutter test environment or mocking complex platform channels:

```dart
// test/task_board_architecture_test.dart
import 'dart:async';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iceberg_pattern_example/application/task_board_cubit.dart';
import 'package:iceberg_pattern_example/data/task_repository.dart';
import 'package:iceberg_pattern_example/domain/task.dart';

void main() {
  group('The Iceberg Pattern Architecture Test Suite', () {
    late StreamController<List<Task>> cloudController;
    late TaskRepository repository;

    setUp(() {
      cloudController = StreamController<List<Task>>.broadcast();
    });

    tearDown(() {
      repository.dispose();
      cloudController.close();
    });

    // 1. Initial Stream Sync Test
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'emits updated task list synchronously upon cloud stream emission',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async {},
          deleteCloudTask: (_) async {},
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (_) {
        cloudController.add([
          (id: '1', title: 'Write Article', isCompleted: false, tags: ['work']),
        ]);
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        equalsTaskBoardState((
          tasks: [(id: '1', title: 'Write Article', isCompleted: false, tags: ['work'])],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 2. The 0ms Optimistic Test (emits before cloud completes)
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'emits optimistic completed status in 0ms before cloud write finishes',
      build: () {
        final completer = Completer<void>();
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) => completer.future, // Hanging future
          deleteCloudTask: (_) async {},
          initialTasks: [
            (id: '1', title: 'Test Task', isCompleted: false, tags: const <String>[]),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.toggleTask('1', false),
      expect: () => [
        equalsTaskBoardState((
          tasks: [(id: '1', title: 'Test Task', isCompleted: true, tags: const <String>[])],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 3. The Rollback & Error Test (reverts state and routes to onError)
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'silently rolls back state and triggers onError on cloud rejection',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async => throw Exception('Cloud network timeout'),
          deleteCloudTask: (_) async {},
          initialTasks: [
            (id: '1', title: 'Test Task', isCompleted: false, tags: const <String>[]),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.toggleTask('1', false),
      wait: const Duration(milliseconds: 15),
      expect: () => [
        // Frame 1: Optimistic toggle
        equalsTaskBoardState((
          tasks: [(id: '1', title: 'Test Task', isCompleted: true, tags: const <String>[])],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
        // Frame 2: Silent rollback to server truth + hasSyncError: true
        equalsTaskBoardState((
          tasks: [(id: '1', title: 'Test Task', isCompleted: false, tags: const <String>[])],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: true,
        )),
      ],
      errors: () => [
        isA<SyncRollbackException>(),
      ],
    );
  });
}
```

---

## 🎯 Summary

The Iceberg Pattern gives developers a principled path past the limitations of traditional Clean Architecture in modern real-time apps:

- **Collapse Asynchrony Early**: Quarantining live streams to the submerged repository engine shields your entire presentation layer from microtask latency and stream lifecycle leaks.
- **Dual-Track Mutations**: Use 0ms optimistic updates for rapid, reversible interactions (like toggling a checkbox) and pessimistic updates for destructive or irreversible actions (like deleting a resource).
- **Stale-While-Revalidate UX**: Avoid flash-of-error screens. Keep cached data visible with a subtle banner while the background engine recovers connection truth.
- **Pure Dart Portability**: When domain models and state machines have zero platform or widget dependencies, your core application logic runs and tests at native speed across Flutter, Jaspr web, and backend services.

Check out the complete runnable codebase in the [BlocSignal Monorepo on GitHub](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/iceberg_pattern).
