# ⚡ BlocSignal Monorepo

> *"With the rigor of Bloc and the flex and speed of Signal"*

`BlocSignal` is a state management framework for Dart and Flutter that bridges the Business Logic Component (BLoC) pattern with Rody Davis's `signals` (v7) primitives. 

This repository is organized as a native Dart workspace and contains the following 8 packages:

| Package | Description | Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state container and observation | [README](./bloc_signals/README.md) |
| **`bloc_signals_flutter`** | Flutter UI bindings, dependency providers, and builders | [README](./bloc_signals_flutter/README.md) |
| **`bloc_signals_riverpod`** | Bidirectional Riverpod interop adapters and extensions | [README](./bloc_signals_riverpod/README.md) |
| **`bloc_signals_hydrate`** | Persistent state storage (`HydratedCubitSignal`, `HydratedBlocSignal`) | [README](./bloc_signals_hydrate/README.md) |
| **`bloc_signals_devtools`** | Dedicated Flutter DevTools extension inspector UI | [README](./bloc_signals_devtools/README.md) |
| **`bloc_signals_test`** | Declarative unit testing utilities for BlocSignal and CubitSignal | [README](./bloc_signals_test/README.md) |
| **`bloc_signals_lint`** | Static analysis lints and IDE diagnostics for BlocSignal | [README](./bloc_signals_lint/README.md) |
| **`otel_bloc_signals`** | OpenTelemetry tracing observer for mapping lifecycle steps to spans | [README](./otel_bloc_signals/README.md) |

---

## ⚡ Key Features

- 🚀 **Synchronous State Propagation**: Eliminates microtask-queue latency found in Stream-based BLoC implementations.
- 🎯 **Fine-Grained Reactivity**: Leverages Rody Davis's signals v7 primitives for highly performant and precise rebuilds.
- 🧹 **Automatic Lifecycle Management**: Automatically manages and tears down effects and listeners via `SignalModel` integration on close.
- 🔍 **Global Observation**: Hook in a `BlocSignalObserver` to easily log, trace, and monitor events and transitions globally.
- 🔀 **Automatic De-duplication**: State transitions are automatically de-duplicated using standard `==` equality or custom `equals`.
- 🛠️ **DevTools & VM Service RPC**: Remote action dispatching, trace panels, diff inspectors, and leak detection via `bloc_signals_devtools`.
- 💾 **State Persistence**: Synchronous initial state hydration across app restarts via `bloc_signals_hydrate`.
- 📊 **OpenTelemetry Tracing**: Built-in support for distributed tracing with standard OpenTelemetry spans via `otel_bloc_signals`.
- 🌁 **Universal Interoperability**: Seamlessly adapt between BLoC, Riverpod, Provider, and Flutter Listenable primitives.

---

## 📚 Documentation

- **[Migration Guide](./plugins/bloc-signals/skills/bloc-signals/migration.md)**: A guide for moving from classic `package:bloc` / `package:flutter_bloc` to `BlocSignal`.
- **[Riverpod Interop & Migration](./plugins/bloc-signals/skills/bloc-signals/riverpod_migration.md)**: Guide to converting between Riverpod providers and `BlocSignal`.
- **[Universal Interoperability Guide](./plugins/bloc-signals/skills/bloc-signals/interoperability.md)**: State bridge across BLoC, Riverpod, and Provider.

---

## 📜 Credits & Acknowledgements

`BlocSignal` is heavily inspired by and builds upon the incredible work of:
- **[Felix Angelov](https://github.com/felangel)** and the original **[bloc](https://pub.dev/packages/bloc)** / **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** libraries.
- **[Rody Davis](https://github.com/roddydavis)** and the **[signals](https://pub.dev/packages/signals)** library.
- **[Remi Rousselet](https://github.com/rrousselGit)** and **[Riverpod](https://riverpod.dev)**.
