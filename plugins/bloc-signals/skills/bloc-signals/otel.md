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
  BlocSignalObserver.addObserver(OtelBlocSignalObserver());
  runApp(const App());
}
```

When `tracer` is omitted, `OtelBlocSignalObserver` resolves `OTelAPI.tracerProvider().getTracer('bloc_signals_otel')`. Pass an `APITracer` in tests or when the application owns custom tracer configuration:

```dart
final tracer = OTelAPI.tracerProvider().getTracer('custom_tracer');
BlocSignalObserver.addObserver(OtelBlocSignalObserver(tracer: tracer));
```

Use `BlocSignalObserver.addObserver(...)` or `MultiBlocSignalObserver` (`CompositeBlocSignalObserver`) when logging, crash reporting, and OpenTelemetry must all receive the same events (duplicate identical observer instances are ignored).

## Span lifecycle

`onEvent` starts a span named `<BlocType>.add(<EventType>)` with `bloc.type` and `event.type` string
attributes.

`onTransition` finds the active span by per-invocation `BlocSignalBase.ambientZoneDispatchTokenKey` (falling back to `(bloc, event)` identity when un-zoned), writes `state.value` using
`state.toString()` (or `stateRedactor`), and records a `'transition'` span event via `addEventNow`.

`onEventCompleted` finds the active span by `ambientZoneDispatchTokenKey` (returning as a no-op if already removed by drop/preemption/error, or falling back to FIFO `(bloc, event)` identity when un-zoned), applies `state.value`, marks the span `SpanStatusCode.Ok`, and ends it.

`onTelemetry` handles operational telemetry. When emitted within an active span:
- It records a Span Event via `addEventNow` with sanitized attributes (converting primitive types and lists via `OTelAPI.attributesFromMap`).
- If the telemetry indicates concurrency contention (`BlocTelemetryKeys.eventDropped` targets the current `dispatchToken`; `BlocTelemetryKeys.taskPreempted` targets the oldest `(bloc, event)` entry whose `dispatchToken != currentToken`), it tags `'bloc.contention': true`, marks the span `SpanStatusCode.Ok`, and immediately ends and removes only that targeted span from active tracking.
When emitted outside an active span (for example, discrete cubit operations), it produces an independent span `<BlocType>.telemetry.<name>`.

`onError` closes only the failing invocation's span when `ambientZoneDispatchTokenKey` is present (preserving unrelated concurrent spans), falling back to ending active spans for the failing bloc only when un-zoned.
When no matching active span exists, it creates and immediately ends `<BlocType>.error`.

Observer hooks accept `BlocSignalBase<dynamic>`, so the same observer receives `BlocSignal` and
`CubitSignal` transitions, telemetry, and errors. A cubit has no event dispatch span. Its ordinary transitions
carry a null event, its operational metrics flow through `emitTelemetry()`, and a reported cubit error with no active span produces a standalone
`<CubitType>.error` span.

`OtelBlocSignalObserver` overrides `onClose` to purge and end lingering active spans associated with the closed container, preventing memory accumulation upon disposal.

## Completion gaps

In standard flows, an event that waits indefinitely does not produce `onEventCompleted`. Concurrency transformer contention (`droppable` drops and `restartable` preemptions) is automatically closed via `onTelemetry` with `'bloc.contention': true`, and handlers with zero state transitions close on `onEventCompleted`. Any lingering spans remain in the observer's active map until an error occurs, the container closes, or capacity eviction triggers.

## Data safety & Redaction

`state.value`, `event.value`, and error messages record `.toString()` by default. To sanitize PII, secrets, or high-cardinality tokens, and to bound attribute sizes, configure `stateRedactor`, `eventRedactor`, `errorRedactor`, and `maxAttributeLength`:

```dart
BlocSignalObserver.addObserver(
  OtelBlocSignalObserver(
    stateRedactor: (bloc, state) {
      if (state is UserProfileState) {
        return 'UserProfile(id: ${state.id}, email: [REDACTED])';
      }
      return state?.toString();
    },
    eventRedactor: (bloc, event) => event is LoginSubmitted ? 'LoginSubmitted([REDACTED])' : event?.toString(),
    errorRedactor: (bloc, error) => error is AuthException ? 'AuthException([REDACTED])' : error.toString(),
    maxAttributeLength: 512,
  ),
);
```

- Returning `null` from `stateRedactor` or `eventRedactor` omits `state.value` or `event.value` respectively.
- Returning `null` from `errorRedactor` omits the span status description and records `'[REDACTED]'` for `exception.message` (in both `OtelBlocSignalObserver.onError` and `traced` / `tracedBloc`).
- `stackTraceRedactor` and `maxStackTraceLength` (falling back to `maxAttributeLength` when `maxStackTraceLength` is omitted) sanitize and bound `exception.stacktrace`; returning `''` omits `exception.stacktrace`.
- `maxAttributeLength` (must be `> 0`) truncates `state.value`, `event.value`, error messages, and stringified `onTelemetry` metadata values.
- `onTelemetry` normalizes `metadata` before passing to `OTelAPI.attributesFromMap`: `null` becomes `'null'`, `bool`/`int`/`double` are preserved, `String` is capped, homogeneous `List<bool>`/`List<int>`/`List<double>` are preserved, mixed numeric `int`/`double` lists are converted to `List<double>`, `List<String>` / mixed / object `Iterable`s (`List`, `Set`) are converted to `List<String>` with each item capped, and `Map` or custom objects are stringified and capped.

Spans are disambiguated using per-invocation zone dispatch tokens (`BlocSignalBase.ambientZoneDispatchTokenKey`) with a FIFO queue fallback per event key when un-zoned, and a chronological oldest-first eviction queue (`maxActiveSpans`). Spans are also concluded on `onEventCompleted` for zero-emit handlers, and in `tracedBloc` (`otel.Context.current.withSpan(span)`) with `bloc.contention = true` when events are dropped or bypassed under concurrency.


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

- **`traced(transformer, {tracer, spanName, errorRedactor, maxAttributeLength, stackTraceRedactor, maxStackTraceLength})`**: Wraps a standard 3-parameter `EventTransformer` in a `BlocEventTransformer` that automatically creates an OpenTelemetry span (`APISpan`), activates `otel.Context.current.withSpan(span)` across synchronous and asynchronous handler execution, and tags `bloc.type` and `event.type` (plus `bloc.contention: true` when the inner handler is dropped or bypassed). If `tracer` (`APITracer?`) is omitted, `OTelAPI.tracerProvider().getTracer('bloc_signals_otel')` is used. Unhandled exceptions are recorded on the span with `SpanStatusCode.Error` (and optional `errorRedactor`, `stackTraceRedactor`, `maxStackTraceLength`, and `maxAttributeLength` sanitization) before rethrowing.
- **`tracedBloc(transformer, {tracer, spanName, errorRedactor, maxAttributeLength, stackTraceRedactor, maxStackTraceLength})`**: Decorates an existing contextual 4-parameter `BlocEventTransformer` with the same OpenTelemetry span instrumentation, `Context.current` activation, contention tagging, and error/stacktrace sanitization options.
