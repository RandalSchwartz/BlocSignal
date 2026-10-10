# OpenTelemetry observer

This reference matches `bloc_signals_otel` (built on `dartastic_opentelemetry_api` and `dartastic_opentelemetry`).

## Setup

Initialize the OpenTelemetry SDK via `OTel.initialize(...)` and install one observer before creating or dispatching to blocs:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

Future<void> main() async {
  await OTel.initialize(serviceName: 'my_app');
  BlocSignalObserver.observer = OtelBlocSignalObserver();
  runApp(const App());
}
```

When `tracer` is omitted, `OtelBlocSignalObserver` resolves `OTelAPI.tracerProvider().getTracer('bloc_signals_otel')`. Pass an `APITracer` in tests or when the application owns custom tracer configuration:

```dart
final tracer = OTelAPI.tracerProvider().getTracer('custom_tracer');
BlocSignalObserver.observer = OtelBlocSignalObserver(tracer: tracer);
```

The global observer is a single slot. Compose observers in application code when logging, crash
reporting, and OpenTelemetry must all receive the same events.

## Span lifecycle

`onEvent` starts a span named `<BlocType>.add(<EventType>)` with `bloc.type` and `event.type` string
attributes.

`onTransition` finds the span by bloc and event identity, writes `state.value` using
`state.toString()` (or `stateRedactor`), and records a `'transition'` span event via `addEventNow`.

`onEventCompleted` finds the span by bloc and event identity, applies `state.value`, marks the span `SpanStatusCode.Ok`, and ends it.

`onTelemetry` handles operational telemetry. When emitted within an active span:
- It records a Span Event via `addEventNow` with sanitized attributes (converting primitive types and lists via `OTelAPI.attributesFromMap`).
- If the telemetry indicates concurrency contention (`BlocTelemetryKeys.eventDropped` or `BlocTelemetryKeys.taskPreempted`), it tags `'bloc.contention': true`, marks the span `SpanStatusCode.Ok`, and immediately ends and removes the span from `_activeSpans`.
When emitted outside an active span (for example, discrete cubit operations), it produces an independent span `<BlocType>.telemetry.<name>`.

`onError` ends every active span for the failing bloc with `SpanStatusCode.Error` and a recorded exception.
When that bloc has no active span, it creates and immediately ends `<BlocType>.error`.

Observer hooks accept `BlocSignalBase<dynamic>`, so the same observer receives `BlocSignal` and
`CubitSignal` transitions, telemetry, and errors. A cubit has no event dispatch span. Its ordinary transitions
carry a null event, its operational metrics flow through `emitTelemetry()`, and a reported cubit error with no active span produces a standalone
`<CubitType>.error` span.

`OtelBlocSignalObserver` overrides `onClose` to purge and end lingering active spans associated with the closed container, preventing memory accumulation upon disposal.

## Completion gaps

In standard flows, an event that waits indefinitely does not produce `onEventCompleted`. Concurrency transformer contention (`droppable` drops and `restartable` preemptions) is automatically closed via `onTelemetry` with `'bloc.contention': true`, and handlers with zero state transitions close on `onEventCompleted`. Any lingering spans remain in the observer's active map until an error occurs, the container closes, or capacity eviction triggers.

## Data safety & Redaction

`state.value` records `state.toString()` by default. To sanitize PII, secrets, or high-cardinality tokens, configure a custom `stateRedactor`:

```dart
BlocSignalObserver.observer = OtelBlocSignalObserver(
  stateRedactor: (bloc, state) {
    if (state is UserProfileState) {
      return 'UserProfile(id: ${state.id}, email: [REDACTED])';
    }
    return state?.toString();
  },
);
```

Spans are disambiguated using a FIFO queue per event key (`Map<String, List<APISpan>>`), preventing span collisions when identical events are dispatched back-to-back. Spans are also concluded on `onEventCompleted` for zero-emit handlers, and in `tracedBloc` when events are dropped under concurrency.


## Test expectations

Use `InMemorySpanExporter` and `maybeInitializeOtelForTest` from `package:dartastic_opentelemetry/testing.dart` and assert:

- span name and type attributes (`span.attributes.getString(...)`);
- the state attribute on a non-equal transition;
- error status (`SpanStatusCode.Error`) and recorded exception (`span.statusDescription`);
- fallback `CubitSignal` error span behavior;
- fallback error span behavior;
- FIFO (oldest-span) eviction behavior when active spans exceed the cap;
- completion on `onEventCompleted` when zero states are emitted.

Clear the test harness (`harness.clear()`) before each test and reset `BlocSignalObserver.observer` after each test.
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

- **`traced(transformer, {tracer, spanName})`**: Wraps a standard 3-parameter `EventTransformer` in a `BlocEventTransformer` that automatically creates an OpenTelemetry span (`APISpan`) tagged with `bloc.type` and `event.type`. If `tracer` (`APITracer?`) is omitted, `OTelAPI.tracerProvider().getTracer('bloc_signals_otel')` is used. Unhandled exceptions are recorded on the span with `SpanStatusCode.Error` before rethrowing.
- **`tracedBloc(transformer, {tracer, spanName})`**: Decorates an existing contextual 4-parameter `BlocEventTransformer` with the same OpenTelemetry span instrumentation.
