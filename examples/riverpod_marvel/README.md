# Riverpod Marvel Port Example (`BlocSignal`)

A direct architectural port of the official Riverpod Marvel example demonstrating how Riverpod asynchronous family providers map to `BlocSignal` containers and `restartable()` search debouncing.

## ✨ Features

- **Riverpod-to-BlocSignal Migration**: Ports `FutureProvider.family` asynchronous queries to `MarvelCharacterBloc` with clean sealed state hierarchies (`MarvelLoading`, `MarvelLoaded`, `MarvelError`).
- **Streamless Debounced Search (`restartable()`)**: Automatically aborts active character search requests when new characters are typed into the search bar.
- **Character Detail Navigation**: Seamless routing to hero detail views with rich biography cards.
- **Zero-Codegen Architecture**: 100% pure Dart 3 records, sealed classes, and signals without `build_runner` or code generators.

## 🔗 Upstream Reference

- Ported directly from Remi Rousselet's [Riverpod Marvel Example](https://github.com/rrousselGit/riverpod/tree/master/examples/marvel).

## 🚀 Running the Example

```bash
cd examples/riverpod_marvel
flutter run
```

## 🧪 Running Tests

```bash
cd examples/riverpod_marvel
flutter test
```
