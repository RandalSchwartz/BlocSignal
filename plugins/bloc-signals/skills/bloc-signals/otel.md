# OpenTelemetry observer

This reference matches `bloc_signals_otel` 0.2.3.

## Setup

Install one observer before creating or dispatching to blocs:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';

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

`onTelemetry` handles operational telemetry. When emitted within an active span:
- It records a Span Event with sanitized attributes (converting primitive types and lists).
- If the telemetry indicates concurrency contention (`BlocTelemetryKeys.eventDropped` or `BlocTelemetryKeys.taskPreempted`), it tags `'bloc.contention': true`, marks the span `StatusCode.ok`, and immediately ends and removes the span from `_activeSpans`.
When emitted outside an active span (for example, discrete cubit operations), it produces an independent span `<BlocType>.telemetry.<name>`.

`onError` ends every active span for the failing bloc with an error status and recorded exception.
When that bloc has no active span, it creates and immediately ends `<BlocType>.error`.

Observer hooks accept `BlocSignalBase<dynamic>`, so the same observer receives `BlocSignal` and
`CubitSignal` transitions, telemetry, and errors. A cubit has no event dispatch span. Its ordinary transitions
carry a null event, its operational metrics flow through `emitTelemetry()`, and a reported cubit error with no active span produces a standalone
`<CubitType>.error` span.

`OtelBlocSignalObserver` overrides `onClose` to purge and end lingering active spans associated with the closed container, preventing memory accumulation upon disposal.

## Completion gaps

In standard flows, an event that emits only an equal state or waits indefinitely does not produce
`onTransition`. However, concurrency transformer contention (`droppable` drops and `restartable` preemptions) is automatically closed via `onTelemetry` with `'bloc.contention': true`. Lingering spans from equal emissions remain in the observer's active map until an error occurs, the container closes, or capacity eviction triggers.

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
Await each bloc's `close()` future during cleanup.

## Traced transformer decorators (`traced` & `tracedBloc`)

`bloc_signals_otel` provides composable transformer decorators that instrument event handling with dedicated OpenTelemetry spans:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';

class OrderBloc extends BlocSignal<OrderEvent, OrderState> {
  OrderBloc() : super(initialState: OrderInitial()) {
    on<SubmitOrder>(
      _onSubmitOrder,
      // Automatically tags spans with bloc.type and records errors:
      blocTransformer: traced(droppable()),
    );
  }
}
```

- **`traced(transformer, {tracer, spanName})`**: Wraps a standard 3-parameter `EventTransformer` in a `BlocEventTransformer` that automatically creates an OpenTelemetry span tagged with `bloc.type` and `event.type`. Unhandled exceptions are recorded on the span before rethrowing.
- **`tracedBloc(transformer, {tracer, spanName})`**: Decorates an existing contextual 4-parameter `BlocEventTransformer` with the same OpenTelemetry span instrumentation.
