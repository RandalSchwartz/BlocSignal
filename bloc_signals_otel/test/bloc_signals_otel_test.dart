// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
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

class TestCubit extends CubitSignal<int> {
  TestCubit() : super(initialState: 0);

  void triggerError() {
    try {
      throw Exception('Cubit async error');
    } on Exception catch (e, st) {
      onError(e, st);
    }
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

    test('instruments events and transitions successfully', () async {
      final bloc = TestBloc();
      expect(bloc.stateValue, equals(0));

      bloc.add(Increment());
      expect(bloc.stateValue, equals(1));
      await bloc.close();

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

    test('instruments errors successfully', () async {
      final bloc = TestBloc(initialState: -1);

      expect(
        () => bloc.add(Increment()),
        throwsArgumentError,
      );
      await bloc.close();

      // We expect 1 span: the event span itself, marked with error status.
      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestBloc.add(Increment)'));
      expect(span.status.code, equals(otel.StatusCode.error));
      expect(span.status.description, contains('Test error'));
    });

    test('instruments error to transient span when no active span exists',
        () async {
      final bloc = TestBloc();
      observer.onError(bloc, ArgumentError('Fallback error'), StackTrace.empty);
      await bloc.close();

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestBloc.error'));
      expect(span.status.code, equals(otel.StatusCode.error));
      expect(span.status.description, contains('Fallback error'));
    });

    test('caps active spans map and evicts oldest spans', () async {
      final customObserver = OtelBlocSignalObserver(
        tracer: tracer,
        maxActiveSpans: 10,
      );
      BlocSignalObserver.observer = customObserver;

      final bloc = TestBloc();
      for (var i = 0; i < 15; i++) {
        customObserver.onEvent(bloc, 'event_$i');
      }
      expect(exporter.exportedSpans, hasLength(5));
      expect(exporter.exportedSpans.first.name, equals('TestBloc.add(String)'));
      await bloc.close();
    });

    test('onClose flushes active spans associated with closed container',
        () async {
      final bloc = TestBloc();
      observer.onEvent(bloc, 'dangling_event');
      expect(exporter.exportedSpans, isEmpty);

      await bloc.close();
      expect(exporter.exportedSpans, hasLength(1));
      expect(
        exporter.exportedSpans.first.name,
        equals('TestBloc.add(String)'),
      );
    });

    test('instruments CubitSignal errors to transient span successfully',
        () async {
      final cubit = TestCubit()..triggerError();
      await cubit.close();

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestCubit.error'));
      expect(span.status.code, equals(otel.StatusCode.error));
      expect(span.status.description, contains('Cubit async error'));
    });

    test(
        'instruments onTelemetry on active span with span event and contention '
        'and ends span on eventDropped', () async {
      final bloc = TestBloc();
      final event = Increment();
      observer.onEvent(bloc, event);

      observer.onTelemetry(
        bloc,
        BlocTelemetryKeys.eventDropped,
        event: event,
        metadata: const {
          'reason': 'in_flight',
          'ratio': 0.75,
          'tags': ['ui', 'gesture'],
        },
      );

      // Dropped event should end immediately without onTransition!
      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestBloc.add(Increment)'));
      expect(span.attributes.get('bloc.contention'), equals(true));
      expect(span.events, hasLength(1));
      final spanEvent = span.events.first;
      expect(spanEvent.name, equals(BlocTelemetryKeys.eventDropped));
      expect(
        spanEvent.attributes.firstWhere((a) => a.key == 'reason').value,
        equals('in_flight'),
      );
      expect(
        spanEvent.attributes.firstWhere((a) => a.key == 'ratio').value,
        equals(0.75),
      );
      await bloc.close();
    });

    test('instruments onTelemetry on active span and ends on taskPreempted',
        () async {
      final bloc = TestBloc();
      final event = Increment();
      observer.onEvent(bloc, event);

      observer.onTelemetry(
        bloc,
        BlocTelemetryKeys.taskPreempted,
        event: event,
        metadata: const {
          'reason': 'superseded',
          'queue': [1, 2],
          'rates': [1.5, 2.5],
          'flags': [true, false],
        },
      );

      // Preempted event should end immediately without onTransition!
      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestBloc.add(Increment)'));
      expect(span.attributes.get('bloc.contention'), equals(true));
      await bloc.close();
    });

    test('instruments onTelemetry outside active span to discrete span',
        () async {
      final cubit = TestCubit();
      observer.onTelemetry(
        cubit,
        'cache_hit',
        metadata: const {
          'key': 'item_42',
          'latency_ms': 5,
          'cached': true,
        },
      );
      await cubit.close();

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TestCubit.telemetry.cache_hit'));
      expect(span.attributes.get('bloc.type'), equals('TestCubit'));
      expect(span.attributes.get('key'), equals('item_42'));
      expect(span.attributes.get('latency_ms'), equals(5));
      expect(span.attributes.get('cached'), equals(true));
    });
  });
}
