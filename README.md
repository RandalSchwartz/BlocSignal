# BlocSignal Monorepo

`BlocSignal` is a state management framework for Dart and Flutter that bridges the Business Logic Component (BLoC) pattern with Rody Davis's `signals` (v7) primitives. 

This repository is organized as a Dart workspace and contains the following packages:

| Package | Description | Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state container and observation | [README](./bloc_signals/README.md) |
| **`bloc_signals_flutter`** | Flutter UI bindings, dependency providers, and builders | [README](./bloc_signals_flutter/README.md) |
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

- **[Migration Guide](./plugins/bloc-signals/skills/bloc-signals/migration.md)**: A guide for moving from classic `package:bloc` / `package:flutter_bloc` to `BlocSignal`.
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

## AI coding-assistant support

The `bloc-signals` agent plugin covers core APIs, Flutter bindings, testing, classic BLoC migration, and OpenTelemetry tracing. Marketplace registration and plugin installation are separate steps.

Google Antigravity imports the plugin directly from this repository:

```bash
agy plugin install https://github.com/RandalSchwartz/BlocSignal
```

Claude Code uses the repository's `blocsignal` marketplace:

```bash
claude plugin marketplace add --scope user RandalSchwartz/BlocSignal
claude plugin install --scope user bloc-signals@blocsignal
```

OpenAI Codex uses the same marketplace and plugin name:

```bash
codex plugin marketplace add RandalSchwartz/BlocSignal
codex plugin add bloc-signals@blocsignal
```

Start a new agent session after installation. Claude Code can instead run `/reload-plugins` in the current session. Rerun the Agy install command when you want to refresh its imported copy.

---

## Credits & Acknowledgements


`BlocSignal` is heavily inspired by and builds upon the incredible work of the following:
- **[Felix Angelov](https://github.com/felangel)** and the original **[bloc](https://pub.dev/packages/bloc)** / **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** libraries, which established the event-driven state container architecture.
- **[Rody Davis](https://github.com/roddydavis)** and the **[signals](https://pub.dev/packages/signals)** library, which provides the high-performance reactive state primitives that make synchronous propagation possible.

Thank you for your immense contributions to the Flutter/Dart ecosystem!
