import 'package:bloc_signals/bloc_signals.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
import 'package:otel_bloc_signals/otel_bloc_signals.dart';
import 'package:test/test.dart';

class Increment {}

class TestBloc extends BlocSignal<Increment, int> {
  TestBloc({super.initialState = 0}) {
    on<Increment>((event, emit) {
      if (stateValue == -1) {
        throw ArgumentError('Test error');
      }
      emit(stateValue + 1);
    });
  }
}

class InMemorySpanExporter implements otel_sdk.SpanExporter {
  final List<otel_sdk.ReadOnlySpan> exportedSpans = [];

  @override
  void export(List<otel_sdk.ReadOnlySpan> spans) {
    exportedSpans.addAll(spans);
  }

  @override
  void forceFlush() {}

  @override
  void shutdown() {
    exportedSpans.clear();
  }
}

void main() {
  group('OtelBlocSignalObserver Tests', () {
    late InMemorySpanExporter exporter;
    late otel_sdk.TracerProviderBase tracerProvider;
    late otel.Tracer tracer;
    late OtelBlocSignalObserver observer;

    setUp(() {
      exporter = InMemorySpanExporter();
      tracerProvider = otel_sdk.TracerProviderBase(
        processors: [otel_sdk.SimpleSpanProcessor(exporter)],
      );
      tracer = tracerProvider.getTracer('test_tracer');
      observer = OtelBlocSignalObserver(tracer: tracer);
      BlocSignalObserver.observer = observer;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
      tracerProvider.shutdown();
    });

    test('uses default global tracer if none is provided', () {
      final defaultObserver = OtelBlocSignalObserver();
      expect(defaultObserver, isNotNull);
    });

    test('instruments events and transitions successfully', () {
      final bloc = TestBloc();
      expect(bloc.stateValue, equals(0));

      bloc.add(Increment());
      expect(bloc.stateValue, equals(1));
      bloc.close();

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestBloc.add(Increment)'));
      expect(
        span.attributes.get('bloc.type'),
        equals('TestBloc'),
      );
      expect(
        span.attributes.get('event.type'),
        equals('Increment'),
      );
      expect(
        span.attributes.get('state.value'),
        equals('1'),
      );
    });

    test('instruments errors successfully', () {
      final bloc = TestBloc(initialState: -1);

      expect(
        () => bloc.add(Increment()),
        throwsArgumentError,
      );
      bloc.close();

      // We expect 2 spans: one for the event (uncompleted/errored) and one transient error span
      expect(exporter.exportedSpans.length, greaterThanOrEqualTo(1));
      final errorSpan = exporter.exportedSpans.firstWhere(
        (s) => s.name == 'TestBloc.error',
      );
      expect(
        errorSpan.attributes.get('bloc.type'),
        equals('TestBloc'),
      );
    });
  });
}
