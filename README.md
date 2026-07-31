<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="BlocSignal Logo" />
    </td>
    <td valign="middle">
      <h1>⚡ BlocSignal</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        A state management framework for Dart and Flutter that bridges the 
        Business Logic Component (BLoC) pattern with Rody Davis's <code>signals</code> (v7) primitives.
      </p>
    </td>
  </tr>
</table> 

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
| **`bloc_signals_otel`** | OpenTelemetry tracing observer for mapping lifecycle steps to spans | [README](./bloc_signals_otel/README.md) |

---

## ⚡ Key Features

- 🚀 **Synchronous State Propagation**: Eliminates microtask-queue latency found in Stream-based BLoC implementations.
- 🎯 **Fine-Grained Reactivity**: Leverages Rody Davis's signals v7 primitives for highly performant and precise rebuilds.
- 🧹 **Automatic Lifecycle Management**: Automatically manages and tears down effects and listeners via `SignalModel` integration on close.
- 🔍 **Global Observation**: Hook in a `BlocSignalObserver` to easily log, trace, and monitor events and transitions globally.
- 🔀 **Automatic De-duplication**: State transitions are automatically de-duplicated using standard `==` equality or custom `equals`.
- 🛠️ **DevTools & VM Service RPC**: Remote action dispatching, trace panels, diff inspectors, and leak detection via `bloc_signals_devtools`.
- 💾 **State Persistence**: Synchronous initial state hydration across app restarts via `bloc_signals_hydrate`.
- 📊 **OpenTelemetry Tracing**: Built-in support for distributed tracing with standard OpenTelemetry spans via `bloc_signals_otel`.
- 🌁 **Universal Interoperability**: Seamlessly adapt between BLoC, Riverpod, Provider, and Flutter Listenable primitives.

---

## 📚 Documentation

- **[Migration Guide](./plugins/bloc-signals/skills/bloc-signals/migration.md)**: Moving from classic `package:bloc` / `package:flutter_bloc` to `BlocSignal`.
- **[Riverpod Interop & Migration](./plugins/bloc-signals/skills/bloc-signals/riverpod_migration.md)**: Converting between Riverpod providers and `BlocSignal`.
- **[Universal Interoperability Guide](./plugins/bloc-signals/skills/bloc-signals/interoperability.md)**: State bridge across BLoC, Riverpod, and Provider.
- **[State Hydration](./plugins/bloc-signals/skills/bloc-signals/hydration.md)**: Persistent state storage and initial hydration semantics.
- **[DevTools Extension](./plugins/bloc-signals/skills/bloc-signals/devtools.md)**: DevTools inspector, timeline trace panel, and memory leak alerts.
- **[Static Analysis & Lints](./plugins/bloc-signals/skills/bloc-signals/lint.md)**: Analyzer rules and IDE diagnostics.
- **[OpenTelemetry Telemetry](./plugins/bloc-signals/skills/bloc-signals/otel.md)**: Distributed tracing spans and observer setup.

---

## 🤖 AI Coding Assistant Skill & Plugin

This repository includes a pre-packaged AI Agent Plugin & Skill bundle (`bloc-signals`) containing architectural best practices, lifecycle contracts, and migration guides for AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex):

- **Skill Bundle**: [`plugins/bloc-signals/skills/bloc-signals/`](./plugins/bloc-signals/skills/bloc-signals/)
- **Marketplace Manifests**: Available via `.claude-plugin` and `.agents/plugins` marketplace definitions.
- **Validation**: Run `dart run tool/validate_agent_plugin.dart` to verify marketplace catalogs and skill bundle integrity.

---

## 📜 Credits & Acknowledgements

`BlocSignal` is heavily inspired by and builds upon the incredible work of:
- **[Felix Angelov](https://github.com/felangel)** and the original **[bloc](https://pub.dev/packages/bloc)** / **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** libraries.
- **[Rody Davis](https://github.com/roddydavis)** and the **[signals](https://pub.dev/packages/signals)** library.
- **[Remi Rousselet](https://github.com/rrousselGit)** and **[Riverpod](https://riverpod.dev)**.
