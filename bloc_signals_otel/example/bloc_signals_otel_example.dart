// Prints are used in this example file to demonstrate OpenTelemetry logs.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// 1. Define the Events
sealed class CounterEvent {}

/// Increment event.
class Increment extends CounterEvent {}

/// 2. Implement the BlocSignal
class CounterBloc extends BlocSignal<CounterEvent, int> {
  /// Create a counter bloc with initial state 0.
  CounterBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
  }
}

/// A simple [SpanExporter] that prints spans to the console.
class SimpleConsoleExporter implements SpanExporter {
  @override
  Future<void> export(List<Span> spans) async {
    for (final span in spans) {
      print(
        'Exported Span: "${span.name}" '
        '[Status: ${span.status}]',
      );
    }
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {}
}

Future<void> main() async {
  // 3. Initialize OpenTelemetry SDK with our Simple Console Exporter
  await OTel.initialize(
    serviceName: 'bloc_signals_otel_example',
    spanProcessor: SimpleSpanProcessor(SimpleConsoleExporter()),
    enableMetrics: false,
    enableLogs: false,
    detectPlatformResources: false,
  );

  final tracer = OTel.tracerProvider().getTracer('otel_bloc_signals_example');

  // 4. Register the global OtelBlocSignalObserver
  BlocSignalObserver.observer = OtelBlocSignalObserver(tracer: tracer);

  print('--- Starting CounterBloc instrumentation example ---');

  final bloc = CounterBloc()
    ..add(Increment())
    ..add(Increment());
  await bloc.close();

  // Shut down OpenTelemetry to flush any remaining spans to the console
  await OTel.shutdown();

  print('--- Finished CounterBloc instrumentation example ---');
}
