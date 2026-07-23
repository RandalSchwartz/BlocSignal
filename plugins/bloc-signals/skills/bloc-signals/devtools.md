# DevTools & Telemetry Guide (`DevToolsBlocSignalObserver`)

This guide details Flutter DevTools inspection and VM service telemetry for `BlocSignal` using `package:bloc_signals_flutter`.

`DevToolsBlocSignalObserver` broadcasts container lifecycle events to the Dart VM service via `developer.postEvent` under `bloc_signal.*` event kinds, enabling real-time DevTools timeline inspection.

---

## 🚀 Key Features

- **Lifecycle Telemetry**: Intercepts `onCreate`, `onEvent`, `onTransition`, `onChange`, `onError`, and `onClose`.
- **Causal Trace Correlation**: Links incoming `add(event)` IDs to their exact caused `emit(state)` transitions.
- **Observer Chaining**: Accepts a `previousObserver` parameter so developers can combine DevTools telemetry with OpenTelemetry (`otel_bloc_signals`) seamlessly.
- **Zero Release Overhead**: Telemetry posting calls are guarded with `kDebugMode` / debug assertions and stripped in production release builds.

---

## 💡 Quick Start

In your `main.dart` entrypoint before `runApp()`:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/material.dart';

void main() {
  // Register DevTools observer (optionally chaining previous observer)
  BlocSignalObserver.observer = DevToolsBlocSignalObserver(
    previousObserver: BlocSignalObserver.observer,
  );

  runApp(const MyApp());
}
```

---

## 📡 VM Service Event Kinds

| VM Service Event | Payload Data |
| :--- | :--- |
| `bloc_signal.onCreate` | `blocType`, `hashCode`, `initialState`, `timestamp` |
| `bloc_signal.onEvent` | `blocType`, `hashCode`, `event`, `timestamp` |
| `bloc_signal.onTransition` | `blocType`, `hashCode`, `event`, `nextState`, `timestamp` |
| `bloc_signal.onChange` | `blocType`, `hashCode`, `currentState`, `nextState`, `timestamp` |
| `bloc_signal.onError` | `blocType`, `hashCode`, `error`, `stackTrace`, `timestamp` |
| `bloc_signal.onClose` | `blocType`, `hashCode`, `timestamp` |
