# OpenTelemetry observer

This reference matches `otel_bloc_signals` 0.1.6.

## Setup

Install one observer before creating or dispatching to blocs:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:otel_bloc_signals/otel_bloc_signals.dart';

void main() {
  BlocSignalObserver.observer = OtelBlocSignalObserver();
  runApp(const App());
}
```

Pass a tracer in tests or when the application owns tracer configuration:

```dart
BlocSignalObserver.observer = OtelBlocSignalObserver(tracer: tracer);
```

The global observer is a single slot. Compose observers in application code when logging, crash
reporting, and OpenTelemetry must all receive the same events.

## Span lifecycle

`onEvent` starts a span named `<BlocType>.add(<EventType>)` with `bloc.type` and `event.type` string
attributes.

`onTransition` finds the span by bloc and event identity, writes `state.value` using
`state.toString()`, marks the span successful, and ends it.

`onError` ends every active span for the failing bloc with an error status and recorded exception.
When that bloc has no active span, it creates and immediately ends `<BlocType>.error`.

Observer hooks accept `BlocSignalBase<dynamic>`, so the same observer receives `BlocSignal` and
`CubitSignal` transitions and errors. A cubit has no event dispatch span. Its ordinary transitions
carry a null event, and a reported cubit error with no active span produces a standalone
`<CubitType>.error` span.

## Completion gaps

An event that emits no state, emits only an equal state, or waits indefinitely does not produce
`onTransition`. Its span remains in the observer's active map until an error for that bloc occurs
or the map reaches 1,000 entries and evicts the oldest span. Closing the bloc does not flush active
spans in the current API.

Account for this behavior before using the observer for latency or completion metrics. Do not add a
timer in application code merely to make traces look complete; fix the observer contract or model
the operation with a span owned by the operation itself.

## Data safety

`state.value` records `state.toString()`. Review state types for personal data, tokens, large
payloads, and high-cardinality identifiers before enabling export. Prefer a custom observer or a
safe state representation when the default string is unsuitable.

Errors close all active spans for the same bloc, not only the event that failed. Concurrent async
events therefore need a focused trace test if exact event-to-error correlation matters.

## Test expectations

Use an in-memory exporter and assert:

- span name and type attributes;
- the state attribute on a non-equal transition;
- error status and recorded exception;
- fallback `CubitSignal` error span behavior;
- fallback error span behavior;
- eviction behavior when active spans exceed the cap;
- the no-transition case when an equal state is emitted.

Reset `BlocSignalObserver.observer` and shut down the tracer provider after each test.
