---
series: "BlocSignal Architecture & Practice"
title: "Solving Riverpod’s Family Provider Cache Dilemma with Signals & mapSignal"
published: true
description: "When separate family providers store parameterized network queries as isolated state silos, updating an entity in one subset creates stale data across others. Here is how a normalized mapSignal store fixes it."
tags: flutter, dart, riverpod, architecture
---

## Eliminating Stale Data Silos & Complex Invalidation Loops in Flutter Apps

> **Key Takeaway**: When separate `family` providers store parameterized network queries as isolated state silos, updating an entity in one subset creates stale data across others. By shifting to a **normalized entity store (`mapSignal`)** and **reactive projections (`computed`)**, cache invalidations, duplicate network calls, and stale relational data disappear completely.

---

### 1. The Real-World Dilemma

In a popular Stack Overflow question ([#79988023](https://stackoverflow.com/questions/79988023/how-to-avoid-stale-data-across-multiple-riverpod-family-providers-that-fetch-ove)), a developer encountered a common architectural bottleneck when using **Riverpod 3 family providers** alongside a backend REST API (e.g. FastAPI/Pydantic):

```plaintext
Column 1 (Planned & In Progress)  ---> ref.watch(tasksProvider(Filter([planned, inProgress])))
Column 2 (In Progress & Done)     ---> ref.watch(tasksProvider(Filter([inProgress, done])))
```

Notice that **Task B** (`inProgress`) is displayed in **both** columns simultaneously.

#### The Two Core Pain Points

1. **Overlapping Subset Inconsistency**:
   If a user moves Task B from `inProgress` to `done`, calling `patchTask(Task B)` modifies the entity on the backend. But on the frontend, which family provider should be updated?
   - Updating only Column 2 leaves Column 1 showing stale data.
   - Calling `ref.invalidate(tasksProvider)` across all families forces a full re-fetch of every filtered list from the server, causing redundant network traffic and UI flashes.

2. **Stale Relational Data**:
   Each `Task` embeds a `lastEditor` `User` object (`User lastEditor`). If user **Robert** renames himself to **Bob**, Task A in memory still displays "Robert" because its embedded snapshot is disconnected from user state updates. Refetching every task query just to reflect a single user name change is inefficient and fragile.

---

### 2. Root Cause: Parameterized Fetchers as Isolated Silos

The root cause of this problem is not unique to Riverpod—it happens in standard BLoC, Redux, or Provider whenever **parameterized fetchers double as local state containers**.

```plaintext
[ Family Key: Filter A ]  --->  Stores [ Task A, Task B ]  (Isolated Silo 1)
[ Family Key: Filter B ]  --->  Stores [ Task B, Task C ]  (Isolated Silo 2)
```

Because `Task B` exists as two separate, duplicated objects across two isolated provider instances:
- Modifying instance B1 inside Silo 1 does **not** update instance B2 in Silo 2.
- Neither provider knows about the other.
- The developer is forced to choose between complex multi-provider mutation loops or blunt-force global cache invalidation.

---

### 3. The Signal Solution: Normalization + Fine-Grained Reactivity

By shifting from *parameterized state silos* to a **Reactive Signals Architecture** (using `package:signals` and `BlocSignal`), the problem simplifies dramatically.

Instead of each family provider managing its own list of entities, we establish two core principles:

1. **Normalized Single Source of Truth**: All entities live in key-value entity maps (`mapSignal`).
2. **Derived Projections**: Filtered views become lightweight `computed` signals that derive their lists directly from the normalized store.

```plaintext
                  +-----------------------------------+
                  |   mapSignal<String, Task> tasks   |  <--- Single Source of Truth
                  +-----------------------------------+
                                /       \
                               /         \
   +---------------------------------+  +---------------------------------+
   | computed() Column 1 (Planned/In) |  | computed() Column 2 (In/Done)  |
   +---------------------------------+  +---------------------------------+
```

---

### 4. Unlocking Granular Reactivity with `mapSignal` (`SignalMap`)

A key enabler for this pattern in Dart is [`mapSignal`](https://dartsignals.dev/packages/signals/value/map/) (`SignalMap` from `package:signals`).

Unlike a standard `signal<Map<K, V>>({})` where modifying a single entry requires replacing or cloning the entire map object, a `mapSignal` provides **key-level fine-grained reactivity**:

```dart
import 'package:signals/signals.dart';

// Single normalized entity stores
final tasks = mapSignal<String, Task>({});
final users = mapSignal<String, User>({});
```

#### Advantage 1: In-Place Entity Updates with Zero Network Overhead
When `patchTask` returns the updated Task B (`status: TaskStatus.done`), you update the normalized store directly:

```dart
// Mutating a single key automatically notifies subscribers
tasks['task_b_id'] = updatedTaskB;
```

What happens next?
- `tasks` triggers reactivity **only** for `task_b_id` and collection subscribers.
- `column1Tasks` (`computed`) automatically re-evaluates and drops Task B (since it is no longer `planned` or `inProgress`).
- `column2Tasks` (`computed`) automatically re-evaluates and retains Task B with its updated `done` status.
- **Zero manual family invalidations required.**
- **Zero secondary API requests.**

#### Advantage 2: Effortless Relational Sync (Solving Problem 2)
To handle nested relations cleanly, tasks store foreign keys (`lastEditorId`) rather than embedded snapshot objects:

```dart
class Task {
  final String uuid;
  final TaskStatus status;
  final String lastEditorId; // Foreign key reference

  const Task({
    required this.uuid,
    required this.status,
    required this.lastEditorId,
  });
}
```

In your UI or View Model, derive the relation reactively:

```dart
Widget build(BuildContext context) {
  // Read editor reactively from the normalized user store
  final editor = users[task.lastEditorId];
  return Text('Last edited by: ${editor?.name ?? "Unknown"}');
}
```

When Robert changes his name to Bob:

```dart
users['robert_id'] = User(id: 'robert_id', name: 'Bob');
```

**Result**: Every widget across the entire application displaying a task edited by Robert immediately re-renders with "Bob". You don't need to sweep through task lists, write manual cascade listeners, or invalidate query endpoints.

---

### 5. Side-by-Side Comparison

| Architectural Aspect | Riverpod Family Provider Silos | Normalized Signals (`mapSignal` + `computed`) |
| :--- | :--- | :--- |
| **State Storage** | Fragmented across parameterized family instances | Single normalized entity map (`mapSignal`) |
| **Subset Filtering** | Separate async network fetch per family key | Client-side `computed()` projection over single store |
| **Entity Mutations** | Must sweep & update all active family parameters | Single key update: `tasks[id] = updatedEntity` |
| **Update Scope** | All-or-nothing provider invalidation | Fine-grained dependency tracking down to affected UI elements |
| **Relational Data** | Embedded snapshots become stale | Reactive foreign-key lookup (`users[task.lastEditorId]`) |
| **Network Requests** | Multiplied per filter combination | Single query populates shared store |

---

### 6. Code Example: Implementing the Pattern

#### Defining Models & Normalized Stores

```dart
import 'package:signals/signals.dart';

enum TaskStatus { planned, inProgress, done }

class Task {
  final String uuid;
  final TaskStatus status;
  final String lastEditorId;

  const Task({
    required this.uuid,
    required this.status,
    required this.lastEditorId,
  });
}

class User {
  final String id;
  final String name;

  const User({required this.id, required this.name});
}

// 1. Single Source of Truth
final tasks = mapSignal<String, Task>({});
final users = mapSignal<String, User>({});
```

#### Creating Reactive Subset Views with `computed`

```dart
// 2. Computed Projections for Columns
final column1Tasks = computed(() {
  return tasks.values
      .where((t) => t.status == TaskStatus.planned || t.status == TaskStatus.inProgress)
      .toList();
});

final column2Tasks = computed(() {
  return tasks.values
      .where((t) => t.status == TaskStatus.inProgress || t.status == TaskStatus.done)
      .toList();
});
```

#### Performing Updates

```dart
// Updating Task B status instantly updates both Column 1 and Column 2 in-memory
void updateTaskStatus(String taskId, TaskStatus newStatus) {
  final current = tasks[taskId];
  if (current != null) {
    tasks[taskId] = Task(
      uuid: current.uuid,
      status: newStatus,
      lastEditorId: current.lastEditorId,
    );
  }
}

// Renaming a user instantly updates every task UI displaying that user
void updateUserName(String userId, String newName) {
  users[userId] = User(id: userId, name: newName);
}
```

---

### 7. Bridge with Existing Ecosystems (`BlocSignal` & Riverpod Interop)

If your app already uses Riverpod or classic BLoC, you don't need to replace your entire framework to leverage this pattern:

- **Riverpod Interop (`bloc_signals_riverpod`)**: Expose the normalized `mapSignal` or `computed` projections as Riverpod providers using `.toBlocSignal(ref)` or signal adapters.
- **BLoC Interop (`BlocSignal`)**: Maintain your event-driven workflow in Cubits/Blocs while backing the internal state with normalized signals (`mapSignal`), combining predictable event handlers with zero-cost reactivity.

---

### Summary

Cache inconsistency and stale relational snapshots are natural side-effects of treating parameterized network queries as isolated state containers. By separating **data storage** (normalized `mapSignal`) from **view filtering** (`computed` signals), state management transforms from a web of manual invalidations into an automated, self-updating reactive pipeline.
