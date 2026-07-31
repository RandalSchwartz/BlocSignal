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

| Package | Purpose | Pub.dev Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state containers, event registry, & VM Service telemetry | 📦 [pub.dev](https://pub.dev/packages/bloc_signals) |
| **`bloc_signals_flutter`** | Flutter UI widgets (`BlocSignalProvider`, `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_flutter) |
| **`bloc_signals_riverpod`** | Bidirectional Riverpod interop adapters (`toBlocSignal(ref)`, `toProvider()`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_riverpod) |
| **`bloc_signals_hydrate`** | Persistent state storage (`HydratedCubitSignal`, `HydratedBlocSignal`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_hydrate) |
| **`bloc_signals_devtools`** | Dedicated Flutter DevTools extension inspector UI | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_devtools) |
| **`bloc_signals_test`** | Declarative unit testing helpers (`blocSignalTest`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_test) |
| **`bloc_signals_lint`** | Static analysis lints & IDE quick-fixes | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_lint) |
| **`bloc_signals_otel`** | OpenTelemetry tracing observers | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_otel) |

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
  bloc_signals_devtools: ^0.1.0
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
