# DevTools & Telemetry Guide (`DevToolsBlocSignalObserver`)

This guide details Flutter DevTools inspection and VM service telemetry for `BlocSignal` using `package:bloc_signals`.

`DevToolsBlocSignalObserver` broadcasts container lifecycle events to the Dart VM service via `developer.postEvent` under `bloc_signal.*` event kinds, enabling real-time DevTools timeline inspection.

---

## 🚀 Key Features

- **Lifecycle Telemetry**: Intercepts `onCreate`, `onEvent`, `onTransition`, `onChange`, `onError`, and `onClose`.
- **Causal Trace Correlation**: Links incoming `add(event)` IDs to their exact caused `emit(state)` transitions.
- **Observer Chaining**: Accepts a `previousObserver` parameter so developers can combine DevTools telemetry with OpenTelemetry (`bloc_signals_otel`) seamlessly.
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

---

## 📡 VM Service RPC Extensions

When `DevToolsBlocSignalObserver` is registered, the following VM Service RPC endpoints are registered via `developer.registerExtension`:

| Method | Parameters | Description |
| :--- | :--- | :--- |
| `ext.bloc_signal.getInstances` | None | Returns a JSON list of all active container instances (`instanceHashCode`, `blocType`, `currentState`, `isClosed`). |
| `ext.bloc_signal.getHistory` | `{"instanceHashCode": 123}` | Returns transition history ring buffer for the target container. |
| `ext.bloc_signal.dispatch` | `{"instanceHashCode": 123, "event": {...}}` | Synthetically dispatches an event over RPC (handles JSON-RPC -32602 on bad format). |

### Custom Event Deserialization
For complex event objects dispatched from DevTools, register deserializers in your app bootstrap:

```dart
DevToolsService.registerEventDeserializer('AddToCartEvent', (json) {
  return AddToCartEvent(itemId: json['itemId'] as String);
});
```

### Zero Release Overhead (`DevToolsService.isEnabled`)
In release builds (`kReleaseMode`), `DevToolsService.isEnabled` is set to `false`. All instance tracking, transition history buffers, and payload serialization are completely skipped for zero runtime memory overhead.

---

## 🎨 Dedicated DevTools Extension (`bloc_signals_devtools`)

`bloc_signals_devtools` is packaged as an official Flutter DevTools extension conforming to the Dart DevTools extension specification.

### 1. Installation
Add `bloc_signals_devtools` to your application's `dev_dependencies`:

```yaml
dev_dependencies:
  bloc_signals_devtools: ^1.0.2
```

### 2. Automatic Discovery
When running your Flutter application in debug mode with `DevToolsBlocSignalObserver` registered, open DevTools via your IDE or terminal (`flutter run`). DevTools automatically discovers `bloc_signals_devtools` through `extension/devtools/config.yaml` and renders the dedicated **BlocSignal** tab in the top navigation bar.

### 3. Architecture & Standalone Embedding
The package is designed with a decoupled architecture:
- `lib/bloc_signals_devtools.dart`: Pure Flutter UI widgets (`BlocSignalsDevToolsExtension`, `InstanceTreeView`, `StateDiffInspector`, `TimelineTracePanel`, `LeakDetectorBadge`) and `BlocSignalsDevToolsController` testable on the Dart VM with zero web-only imports.
- `lib/main.dart`: Web entrypoint wrapping `DevToolsExtension` and bridging `serviceManager`, precompiled into `extension/devtools/build/` for distribution.

For custom embedding or standalone tooling outside DevTools:

```dart
import 'package:bloc_signals_devtools/bloc_signals_devtools.dart';
import 'package:flutter/material.dart';

Widget buildInspector(List<Map<String, dynamic>> instances, List<Map<String, dynamic>> history) {
  return BlocSignalsDevToolsExtension(
    instances: instances,
    history: history,
  );
}
```

