# BlocSignal Monorepo

`BlocSignal` is a state management framework for Dart and Flutter that bridges the Business Logic Component (BLoC) pattern with Rody Davis's `signals` (v7) primitives. 

This repository is organized as a Dart workspace and contains the following packages:

| Package | Description | Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state container and observation | [README](./bloc_signals/README.md) |
| **`bloc_signals_flutter`** | Flutter UI bindings, dependency providers, and builders | [README](./bloc_signals_flutter/README.md) |
| **`bloc_signals_test`** | Declarative unit testing utilities for BlocSignal and CubitSignal | [README](./bloc_signals_test/README.md) |
| **`otel_bloc_signals`** | OpenTelemetry tracing observer for mapping lifecycle steps to spans | [README](./otel_bloc_signals/README.md) |


---

## Key Features

- ⚡ **Synchronous State Propagation**: Eliminates microtask-queue latency found in Stream-based BLoC implementations.
- 🎯 **Fine-Grained Reactivity**: Leverages Rody Davis's signals v7 primitives for highly performant and precise rebuilds.
- 🧹 **Automatic Lifecycle Management**: Automatically manages and tears down effects and listeners via `SignalModel` integration on close.
- 🔍 **Global Observation**: Hook in a `BlocSignalObserver` to easily log, trace, and monitor events and transitions globally.
- 🔀 **Automatic De-duplication**: State transitions are automatically de-duplicated using standard `==` equality.
- 📊 **OpenTelemetry Tracing**: Built-in support for distributed tracing with standard OpenTelemetry spans via `otel_bloc_signals`.

---

## Documentation

- **[Migration Guide](./skills/bloc-signals/migration.md)**: A comprehensive guide to transitioning from classic `package:bloc` / `package:flutter_bloc` to `BlocSignal`.
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

---

## AI Coding Assistant Skills

This repository includes a pre-packaged [AI Coding Skill](https://context7.com/skills) representing all the best practices, lifecycle structures, and FAQs for using `BlocSignal`. If you develop with AI code assistants (like Gemini, Claude Code, or Cursor), you can install this skill globally or locally to guide your assistant's code generation:

```bash
npx ctx7@latest skills install RandalSchwartz/BlocSignal bloc-signals
```

---

## Credits & Acknowledgements


`BlocSignal` is heavily inspired by and builds upon the incredible work of the following:
- **[Felix Angelov](https://github.com/felangel)** and the original **[bloc](https://pub.dev/packages/bloc)** / **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** libraries, which established the event-driven state container architecture.
- **[Rody Davis](https://github.com/roddydavis)** and the **[signals](https://pub.dev/packages/signals)** library, which provides the high-performance reactive state primitives that make synchronous propagation possible.

Thank you for your immense contributions to the Flutter/Dart ecosystem!

