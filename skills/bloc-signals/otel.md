# BlocSignal OpenTelemetry (otel_bloc_signals)

This guide details how to observe and trace event lifecycles, state transitions, and exceptions using `otel_bloc_signals`.

---

## 🚀 Instrumentation with `OtelBlocSignalObserver`

`OtelBlocSignalObserver` maps the lifecycle steps of a `BlocSignal` directly to OpenTelemetry tracer spans. It tracks the duration of async events, matches transition states, and routes errors directly to the active span.

### Setup
Register the observer globally before your application starts:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:otel_bloc_signals/otel_bloc_signals.dart';

void main() {
  // Register the Otel observer globally
  BlocSignalObserver.observer = OtelBlocSignalObserver();
  
  runApp(const MyApp());
}
```

---

## 🔍 Observing Lifecycle Hooks

The observer overrides `BlocSignalObserver` methods to generate trace telemetry:

1. **`onEvent`**: Starts an OpenTelemetry span named `${bloc.runtimeType}.add(${event.runtimeType})` when an event is added.
2. **`onTransition`**: Updates the active event span with the target state value (`state.value`), marks the span status as `ok`, and terminates the span.
3. **`onError`**: Captures exceptions, records them on the active event span (or fallback error span), updates the status to `error`, and logs the stack trace.

---

## 🛡️ Telemetry Best Practices

* **Span Leak Prevention**: Active span tracking maps are capped at a maximum of 1,000 items. If event handlers trigger transitions that bypass normal pipelines (or are de-duplicated), the oldest spans are evicted and completed automatically to prevent memory leaks.
* **Error span identity hash-matching**: Exceptions are identity hash-matched against the active bloc ID to map errors directly back to the triggering event span rather than spawning disconnected generic error spans.
