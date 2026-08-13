# Flutter Todos Example (`BlocSignal`)

A flagship reactive Todos application demonstrating state management, filtering derivations via `computed()` signals, and statistics tracking with `BlocSignal`.

## ✨ Features

- **Reactive State Management**: Complete CRUD operations (Add, Toggle, Delete, Clear Completed, Toggle All) managed with `TodosBlocSignal`.
- **Streamless Derivations (`computed()`)**: Derives `filteredTodos`, `activeCount`, and `completedCount` reactively using pure Dart computed signals—eliminating complex Rx stream combiners.
- **Segmented Filtering**: Seamlessly switches between `All`, `Active`, and `Completed` views with 0ms UI delay.
- **Stats Tab**: Live dashboard showing real-time active and completed task counters.

## 🔗 Upstream Reference

- Inspired by the canonical [flutter_todos](https://bloclibrary.dev/tutorials/flutter-todos/) architecture from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_todos
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_todos
flutter test
```
