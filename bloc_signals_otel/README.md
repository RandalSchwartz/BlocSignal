# ⚡ bloc_signals_otel

> *"With the rigor of Bloc and the flex and speed of Signal"*

OpenTelemetry tracing instrumentation for `BlocSignal` state containers.

This package provides `OtelBlocSignalObserver`, a custom `BlocSignalObserver` that maps BLoC events, state transitions, and exception tracebacks into OpenTelemetry spans for end-to-end distributed tracing.

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

- 📊 **Span Correlation**: Maps incoming BLoC events directly to active OpenTelemetry trace spans.
- 🚨 **Error Tracing**: Captures exceptions in `onError` and attaches identity hash-matched stack traces to the active span.
- 🛡️ **Memory-Leak Protection**: Internal active span map capped at 1,000 items with LRU eviction to prevent heap leaks.

---

## 🚀 Getting Started

Add `bloc_signals_otel` to your `pubspec.yaml`:

```yaml
dependencies:
  bloc_signals: ^0.2.6
  bloc_signals_otel: ^0.2.3
  opentelemetry: ^0.1.0
```

---

## 💡 Quick Example

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:opentelemetry/api.dart' as otel;

void main() {
  final tracer = otel.globalTracerProvider.getTracer('my_app');

  // Register OpenTelemetry observer globally
  BlocSignalObserver.observer = OtelBlocSignalObserver(tracer: tracer);

  final bloc = CounterBloc();
  bloc.add(Increment()); // Automatically generates OpenTelemetry spans!
}
```

---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing OpenTelemetry span correlation, error traceback matching, and tracing observer guidelines for `BlocSignal`.

If you develop with AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex), you can load the [`bloc-signals`](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) skill bundle to guide your assistant's code generation and analysis.

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
