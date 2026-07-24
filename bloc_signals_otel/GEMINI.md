# GEMINI: `otel_bloc_signals` Developer Documentation

Developer-focused notes on the architecture, decisions, and codebase details of the `otel_bloc_signals` OpenTelemetry instrumentation package.

---

## Architecture & Layout

This package is a pure Dart library structured to bridge `BlocSignal` lifecycle metrics with the OpenTelemetry SDK.

### File Structure
- `lib/otel_bloc_signals.dart`: Main package entrypoint, exporting the observer.
- `lib/src/otel_bloc_signal_observer.dart`: Core implementation of `OtelBlocSignalObserver`.
- `test/otel_bloc_signals_test.dart`: Test suite validating span creation, tagging, status updates, and error handling.

---

## Implementation Decisions

1. **Pure Dart Target**: The package targets pure Dart instead of Flutter. This guarantees tracing capabilities are available across command-line applications, backend services, and Flutter user interfaces alike.
2. **Span Tracking Key**: Spans are tracked inside a hash map using a unique composite key combining the identity hash codes of the bloc and the event (`${identityHashCode(bloc)}_${identityHashCode(event)}`). This prevents collision issues if multiple blocs or events run concurrently.
3. **No-leak Lifecycle mapping**: Active span objects are popped from the state tracking map as soon as their transition is recorded to prevent memory leak accumulation over time.
