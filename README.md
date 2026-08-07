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

The `BlocSignal` monorepo consists of 10 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |

---

## ⚡ Key Features

- 🚀 **Synchronous State Propagation**: Eliminates microtask-queue latency found in Stream-based BLoC implementations.
- 🎯 **Fine-Grained Reactivity**: Leverages Rody Davis's signals v7 primitives for highly performant and precise rebuilds.
- 🧹 **Automatic Lifecycle Management**: Automatically manages and tears down effects and listeners via `SignalModel` integration on close.
- 🔍 **Global Observation**: Hook in a `BlocSignalObserver` to easily log, trace, and monitor events and transitions globally.
- 🔀 **Automatic De-duplication**: State transitions are automatically de-duplicated using standard `==` equality or custom `equals`.
- 🛠️ **DevTools & VM Service RPC**: Remote action dispatching, trace panels, diff inspectors, and leak detection via `bloc_signals_devtools`.
- 💾 **State Persistence**: Synchronous initial state hydration across app restarts via `bloc_signals_hydrate`.
- ↩️ **Undo & Redo Replay**: Automatic state history tracking, stack limits, and state filtering via `bloc_signals_replay`.
- 📊 **OpenTelemetry Tracing**: Built-in support for distributed tracing with standard OpenTelemetry spans via `bloc_signals_otel`.
- 🌁 **Universal Interoperability**: Seamlessly adapt between BLoC, Riverpod, Provider, and Flutter Listenable primitives.

---

## 📖 Background & Architecture References

`BlocSignal` combines two foundational pillars of the Dart & Flutter state management ecosystem:
- **[BLoC Architecture (bloclibrary.dev)](https://bloclibrary.dev)**: Event-driven state machine discipline, state separation, and enterprise observability (`BlocSignalObserver`).
- **[Signals Primitives (signals.dart)](https://pub.dev/packages/signals)**: Fine-grained reactive dependency graphs and zero-latency value holding.

### Key Architectural Differences & Design Choices:
- ⚡ **Synchronous vs. Asynchronous Emission**: Unlike classic `package:bloc` which dispatches state changes on microtask-queue Streams, `BlocSignal` updates propagate **synchronously**. Calling `emit(newState)` triggers downstream calculations and widget rebuilds in the exact same frame.
- 🔑 **Named Constructor Initial State (`initialState:`)**: Constructors require the named parameter `initialState:` (for example, `: super(initialState: 0)`), unlike Felix BLoC's positional `: super(0)`.
- 📊 **Explicit State Value Access (`stateValue`)**: Use `stateValue` (or `state.value`) to read raw `StateType` values in methods or event handlers (for example, `emit(stateValue + 1)`), while `state` exposes `ReadonlySignal<StateType>` for reactive signal bindings.
- 🎯 **`context.select<B, R>` 2-Argument Generic Signature**: Unlike Riverpod (3 generic arguments) or classic `flutter_bloc`, `context.select<B, R>` takes **2** generic type parameters (`<Bloc, SelectedType>`) and passes the `bloc` instance directly to the callback: `(bloc) => bloc.stateValue.property`.
- 📦 **Zero `RepositoryProvider` Bloat**: Dependency injection in `BlocSignal` is handled directly via `BlocSignalProvider` (or Riverpod/Jaspr context providers) without forcing a separate `RepositoryProvider` wrapper.
- 🔒 **Streamless Event Concurrency**: Event concurrency transformers (`droppable`, `sequential`, `restartable`, `Mutex`) run via pure Dart higher-order functions without stream allocations or Rx dependencies.

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
