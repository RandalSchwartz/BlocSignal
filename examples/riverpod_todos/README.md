# Riverpod Todos Port Example (`CubitSignal`)

A direct architectural port of the official Riverpod Todos example demonstrating how Riverpod's `StateNotifierProvider` and provider filtering map to `CubitSignal` with `computed()` signals.

## ✨ Features

- **Riverpod-to-CubitSignal Migration**: Maps Riverpod's `StateNotifier` to `TodosCubit` with pragmatic imperative methods (`addTodo`, `toggle`, `edit`, `remove`, `toggleAll`, `clearCompleted`).
- **Reactive Derivations (`computed()`)**: Exposes `filteredTodos`, `uncompletedCount`, and `completedCount` directly on the cubit, replacing Riverpod's dependent derived providers.
- **Custom Equality Comparator**: Employs `equals: listEquals` to cleanly de-duplicate identical list states without requiring manual `props` lists or code generation.
- **Granular Rebuilds**: Uses `SignalBuilder` to bind directly to reactive signals within individual list tiles.

## 🔗 Upstream Reference

- Ported directly from Remi Rousselet's [Riverpod Todos Example](https://github.com/rrousselGit/riverpod/tree/master/examples/todos).

## 🚀 Running the Example

```bash
cd examples/riverpod_todos
flutter run
```

## 🧪 Running Tests

```bash
cd examples/riverpod_todos
flutter test
```
