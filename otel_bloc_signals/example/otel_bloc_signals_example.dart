// Prints are used in this example file to demonstrate OpenTelemetry logs.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:otel_bloc_signals/otel_bloc_signals.dart';

/// 1. Define the Events
sealed class CounterEvent {}

/// Increment event.
class Increment extends CounterEvent {}

/// 2. Implement the BlocSignal
class CounterBloc extends BlocSignal<CounterEvent, int> {
  /// Create a counter bloc with initial state 0.
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    unawaited(Future.value(super.onEvent(event)));
    switch (event) {
      case Increment():
        emit(stateValue + 1);
    }
  }
}

/// A simple [otel_sdk.SpanExporter] that prints spans to the console.
class SimpleConsoleExporter implements otel_sdk.SpanExporter {
  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) {
    for (final span in spans) {
      print(
        'Exported Span: "${span.name}" '
        '[Attributes: ${span.attributes}, Status: ${span.status.code}]',
      );
    }
  }

  @override
  void forceFlush() {}

  @override
  void shutdown() {}
}

void main() {
  // 3. Initialize OpenTelemetry SDK with our Simple Console Exporter
  final tracerProvider = otel_sdk.TracerProviderBase(
    processors: [
      otel_sdk.SimpleSpanProcessor(SimpleConsoleExporter()),
    ],
  );

  final tracer = tracerProvider.getTracer('otel_bloc_signals_example');

  // 4. Register the global OtelBlocSignalObserver
  BlocSignalObserver.observer = OtelBlocSignalObserver(tracer: tracer);

  print('--- Starting CounterBloc instrumentation example ---');

  // 5. Instantiate and use the BLoC with cascade calls
  CounterBloc()
    ..add(Increment())
    ..add(Increment())
    ..close();

  // Shut down the tracer provider to flush the remaining spans to console
  tracerProvider.shutdown();

  print('--- Finished CounterBloc instrumentation example ---');
}
