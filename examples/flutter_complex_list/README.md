# Flutter Complex List Example (`BlocSignal`)

A complex interactive list management example featuring item selection, batch operations, and fine-grained rebuild optimization.

## ✨ Features

- **Multi-Selection & Batch Operations**: Supports toggling individual items, batch selecting/deselecting all items, and batch deleting selected items.
- **Reactive Derivations (`computed()`)**: Exposes reactive `selectedCount` and `isAllSelected` computed signals directly on the bloc for 0-latency header statistics.
- **Granular Rebuild Isolation**: Uses `BlocSignalSelector` to rebuild the list view only when the underlying item list structure changes.
- **Exhaustive Event Coordination**: Sealed events (`ItemToggled`, `ItemDeleted`, `SelectAllToggled`, `BatchDeleted`, `ItemAdded`) handled deterministically.

## 🔗 Upstream Reference

- Inspired by the [flutter_complex_list](https://bloclibrary.dev/tutorials/flutter-complex-list/) example from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_complex_list
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_complex_list
flutter test
```
