<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_devtools" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_devtools</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Dedicated Flutter DevTools extension UI for inspecting <code>BlocSignal</code> and <code>CubitSignal</code> 
        containers, tracing event-to-transition timelines, inspecting state diffs, and warning against memory leaks.
      </p>
    </td>
  </tr>
</table>

---

## 🌐 Ecosystem Packages

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

- 🌳 **Instance Tree View**: Searchable list of active container instances, state values, types, and closure status.
- ⏱️ **Timeline Trace Panel**: Chronological timeline mapping events ➔ transitions ➔ state updates per container instance.
- 🔀 **State Diff Inspector**: Interactive object diff viewer highlighting `currentState` vs `nextState`.
- 🚨 **Leak Detector & Warnings**: Alert badge displaying active vs closed container counts and retain warnings.

---

## 🚀 Getting Started

Add `bloc_signals_devtools` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  bloc_signals_devtools: ^0.9.0
```

---

## 💡 Usage Example

```dart
import 'package:bloc_signals_devtools/bloc_signals_devtools.dart';
import 'package:flutter/material.dart';

Widget buildInspector(
  List<Map<String, dynamic>> instances,
  List<Map<String, dynamic>> history,
) {
  return BlocSignalsDevToolsExtension(
    instances: instances,
    history: history,
  );
}
```

---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing VM Service RPC extensions, DevTools inspector usage, and telemetry protocols for `BlocSignal`.

If you develop with AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex), you can load the [`bloc-signals`](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) skill bundle to guide your assistant's code generation and analysis.

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
