# BlocSignal Monorepo

`BlocSignal` is a state management framework for Dart and Flutter that bridges the Business Logic Component (BLoC) pattern with Rody Davis's `signals` (v7) primitives. 

This repository is organized as a Dart workspace and contains the following packages:

| Package | Description | Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state container and observation | [README](./bloc_signals/README.md) |
| **`bloc_signals_flutter`** | Flutter UI bindings, dependency providers, and builders | [README](./bloc_signals_flutter/README.md) |

---

## Key Features

- ⚡ **Synchronous State Propagation**: Eliminates microtask-queue latency found in Stream-based BLoC implementations.
- 🎯 **Fine-Grained Reactivity**: Leverages Rody Davis's signals v7 primitives for highly performant and precise rebuilds.
- 🧹 **Automatic Lifecycle Management**: Automatically manages and tears down effects and listeners via `SignalModel` integration on close.
- 🔍 **Global Observation**: Hook in a `BlocSignalObserver` to easily log, trace, and monitor events and transitions globally.
- 🔀 **Automatic De-duplication**: State transitions are automatically de-duplicated using standard `==` equality.

---

## Documentation

- **[Migration Guide](./MIGRATION.md)**: A comprehensive guide to transitioning from classic `package:bloc` / `package:flutter_bloc` to `BlocSignal`.
- **API Documentation**: Each package contains detailed HTML documentation. You can generate it by running `dart doc` inside each package directory.

---

## Development

We use native Dart workspaces (requires SDK 3.5+) for local development.

### Setup
Run `dart pub get` from the root workspace directory to resolve all dependencies across all packages.

### Run Tests
- Core Package: `cd bloc_signals && dart test`
- Flutter Package: `cd bloc_signals_flutter && flutter test`
- Example App: `cd bloc_signals_flutter/example && flutter test`
