// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    as otel;
import 'package:test/test.dart';

class Increment {
  const Increment();
}

class CustomMetadataObject {
  const CustomMetadataObject(this.label);
  final String label;

  @override
  String toString() => 'Custom($label)';
}

class ZeroEmitBloc extends BlocSignal<String, int> {
  ZeroEmitBloc() : super(initialState: 0) {
    on<String>((event, emit) {
      // 0 emissions
    });
  }
}

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

void main() {
  group('(Issue #352) OtelBlocSignalObserver Tests', () {
    late TestHarness harness;
    late InMemorySpanExporter exporter;
    late otel.APITracer tracer;
    late OtelBlocSignalObserver observer;

    setUpAll(() async {
      harness = await maybeInitializeOtelForTest(
        serviceName: 'bloc_signals_otel_test',
      );
      exporter = harness.spans;
    });

    setUp(() {
      harness.clear();
      tracer = OTel.tracerProvider().getTracer('test_tracer');
      observer = OtelBlocSignalObserver(tracer: tracer);
      BlocSignalObserver.observer = observer;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
    });

    test(
      '(Issue #352) uses default global OTelAPI tracerProvider if none is '
      'provided',
      () async {
        final defaultObserver = OtelBlocSignalObserver();
        BlocSignalObserver.observer = defaultObserver;

        final bloc = TestBloc();
        bloc.add(const Increment());
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestBloc.add(Increment)'));
        expect(span.instrumentationScope.name, equals('bloc_signals_otel'));
      },
    );

    test(
      '(Issue #352) instruments events and transitions successfully',
      () async {
        final bloc = TestBloc();
        expect(bloc.stateValue, equals(0));

        bloc.add(const Increment());
        expect(bloc.stateValue, equals(1));
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestBloc.add(Increment)'));
        expect(
          span.attributes.getString('bloc.type'),
          equals('TestBloc'),
        );
        expect(
          span.attributes.getString('event.type'),
          equals('Increment'),
        );
        expect(
          span.attributes.getString('state.value'),
          equals('1'),
        );
        expect(span.spanEvents, hasLength(1));
        final transitionEvent = span.spanEvents!.first;
        expect(transitionEvent.name, equals('transition'));
        expect(
          transitionEvent.attributes?.getString('state.value'),
          equals('1'),
        );
        expect(
          transitionEvent.attributes?.getString('event.value'),
          equals("Instance of 'Increment'"),
        );
      },
    );

    test('(Issue #352) instruments errors successfully', () async {
      final bloc = TestBloc(initialState: -1);

      expect(
        () => bloc.add(const Increment()),
        throwsArgumentError,
      );
      await bloc.close();

      // We expect 1 span: the event span itself, marked with error status.
      expect(exporter.spans, hasLength(1));
      final span = exporter.spans.first;
      expect(span.name, equals('TestBloc.add(Increment)'));
      expect(span.status, equals(otel.SpanStatusCode.Error));
      expect(span.statusDescription, contains('Test error'));
    });

    test(
      '(Issue #352) instruments error to transient span when no active span '
      'exists',
      () async {
        final bloc = TestBloc();
        observer.onError(
          bloc,
          ArgumentError('Fallback error'),
          StackTrace.empty,
        );
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestBloc.error'));
        expect(span.status, equals(otel.SpanStatusCode.Error));
        expect(span.statusDescription, contains('Fallback error'));
      },
    );

    test(
      '(Issue #352) caps active spans map and evicts oldest spans',
      () async {
        final customObserver = OtelBlocSignalObserver(
          tracer: tracer,
          maxActiveSpans: 10,
        );
        BlocSignalObserver.observer = customObserver;

        final bloc = TestBloc();
        for (var i = 0; i < 15; i++) {
          customObserver.onEvent(bloc, 'event_$i');
        }
        expect(exporter.spans, hasLength(5));
        expect(exporter.spans.first.name, equals('TestBloc.add(String)'));
        await bloc.close();
      },
    );

    test(
      '(Issue #303: F12, Issue #352) evicts spans strictly FIFO (oldest first) '
      'even when earlier spans are recently touched',
      () async {
        final customObserver = OtelBlocSignalObserver(
          tracer: tracer,
          maxActiveSpans: 2,
        );
        BlocSignalObserver.observer = customObserver;

        final bloc = TestBloc();

        // 1. Dispatch event A (first-in), creating span A.
        customObserver.onEvent(bloc, 'event_A');
        expect(exporter.spans, isEmpty);

        // 2. Dispatch event B (second-in), creating span B.
        customObserver.onEvent(bloc, 'event_B');
        expect(exporter.spans, isEmpty);

        // 3. Touch event A via onTransition with a new state.
        // In an LRU scheme, event A would now be the most recently used.
        // In FIFO, event A remains the oldest created span.
        customObserver.onTransition(bloc, 'event_A', 1);

        // 4. Dispatch event C, which exceeds maxActiveSpans (2) and
        // triggers eviction.
        customObserver.onEvent(bloc, 'event_C');

        // Exactly 1 span should be evicted and ended.
        expect(exporter.spans, hasLength(1));

        // Under FIFO eviction, event A (the oldest inserted span) is evicted,
        // even though it was touched more recently than event B.
        final evictedSpan = exporter.spans.first;
        expect(evictedSpan.name, equals('TestBloc.add(String)'));
        expect(evictedSpan.attributes.getString('state.value'), equals('1'));

        await bloc.close();
      },
    );

    test(
      '(Issue #352) onClose flushes active spans associated with closed '
      'container',
      () async {
        final bloc = TestBloc();
        observer.onEvent(bloc, 'dangling_event');
        expect(exporter.spans, isEmpty);

        await bloc.close();
        expect(exporter.spans, hasLength(1));
        expect(
          exporter.spans.first.name,
          equals('TestBloc.add(String)'),
        );
      },
    );

    test(
      '(Issue #352) instruments CubitSignal errors to transient span '
      'successfully',
      () async {
        final cubit = TestCubit()..triggerError();
        await cubit.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestCubit.error'));
        expect(span.status, equals(otel.SpanStatusCode.Error));
        expect(span.statusDescription, contains('Cubit async error'));
      },
    );

    test(
      '(Issue #278, Issue #352) instruments onTelemetry on active span with '
      'span event and contention and ends span on eventDropped',
      () async {
        final bloc = TestBloc();
        const event = Increment();
        observer.onEvent(bloc, event);

        observer.onTelemetry(
          bloc,
          BlocTelemetryKeys.eventDropped,
          event: event,
          metadata: const {
            'reason': 'in_flight',
            'ratio': 0.75,
            'tags': ['ui', 'gesture'],
            'custom': CustomMetadataObject('dropped_meta'),
            'nullable': null,
          },
        );

        // Dropped event should end immediately without onTransition!
        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestBloc.add(Increment)'));
        expect(span.attributes.getBool('bloc.contention'), equals(true));
        expect(span.spanEvents, hasLength(1));
        final spanEvent = span.spanEvents!.first;
        expect(spanEvent.name, equals(BlocTelemetryKeys.eventDropped));
        expect(
          spanEvent.attributes?.getString('reason'),
          equals('in_flight'),
        );
        expect(
          spanEvent.attributes?.getDouble('ratio'),
          equals(0.75),
        );
        expect(
          spanEvent.attributes?.getStringList('tags'),
          equals(['ui', 'gesture']),
        );
        expect(
          spanEvent.attributes?.getString('custom'),
          equals('Custom(dropped_meta)'),
        );
        expect(
          spanEvent.attributes?.getString('nullable'),
          equals('null'),
        );
        await bloc.close();
      },
    );

    test(
      '(Issue #278, Issue #352) instruments onTelemetry on active span and '
      'ends on taskPreempted',
      () async {
        final bloc = TestBloc();
        const event = Increment();
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
        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestBloc.add(Increment)'));
        expect(span.attributes.getBool('bloc.contention'), equals(true));
        final spanEvent = span.spanEvents!.first;
        expect(spanEvent.attributes?.getIntList('queue'), equals([1, 2]));
        expect(
          spanEvent.attributes?.getDoubleList('rates'),
          equals([1.5, 2.5]),
        );
        expect(
          spanEvent.attributes?.getBoolList('flags'),
          equals([true, false]),
        );
        await bloc.close();
      },
    );

    test(
      '(Issue #352) instruments onTelemetry without active span creating '
      'ad-hoc span',
      () async {
        final cubit = TestCubit();

        observer.onTelemetry(
          cubit,
          'cache_hit',
          metadata: const {
            'key': 'item_42',
            'latency_ms': 5,
            'cached': true,
            'nullable': null,
          },
        );

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TestCubit.telemetry.cache_hit'));
        expect(span.attributes.getString('bloc.type'), equals('TestCubit'));
        expect(span.attributes.getString('key'), equals('item_42'));
        expect(span.attributes.getInt('latency_ms'), equals(5));
        expect(span.attributes.getBool('cached'), equals(true));
        expect(span.attributes.getString('nullable'), equals('null'));
        await cubit.close();
      },
    );

    test(
      '(Issue #310: F12, Issue #352) repeated identical const events generate '
      'distinct spans without collisions',
      () async {
        final bloc = TestBloc();
        const event = Increment();

        bloc.add(event);
        bloc.add(event);

        expect(bloc.stateValue, equals(2));
        await bloc.close();

        expect(exporter.spans, hasLength(2));
        expect(
          exporter.spans[0].name,
          equals('TestBloc.add(Increment)'),
        );
        expect(
          exporter.spans[1].name,
          equals('TestBloc.add(Increment)'),
        );
      },
    );

    test(
      '(Issue #352) handlers with 0 emissions complete and close span via '
      'onEventCompleted without leaks',
      () async {
        final bloc = ZeroEmitBloc();

        bloc.add('noop');
        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('ZeroEmitBloc.add(String)'));
        expect(span.status, equals(otel.SpanStatusCode.Ok));

        await bloc.close();
      },
    );

    test(
      '(Issue #352) stateRedactor formats or redacts state.value span '
      'attribute',
      () async {
        final customObserver = OtelBlocSignalObserver(
          tracer: tracer,
          stateRedactor: (bloc, state) => '[REDACTED]',
        );
        BlocSignalObserver.observer = customObserver;

        final bloc = TestBloc();
        bloc.add(const Increment());
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(
          span.attributes.getString('state.value'),
          equals('[REDACTED]'),
        );
      },
    );

    group('(Issue #422) Redaction, Truncation, and Metadata Normalization', () {
      test(
        '(Issue #422: F01) eventRedactor formats or omits event.value on '
        'transition events',
        () async {
          final customObserver = OtelBlocSignalObserver(
            tracer: tracer,
            eventRedactor: (bloc, event) => '[REDACTED_EVENT]',
          );
          BlocSignalObserver.observer = customObserver;

          final bloc = TestBloc()..add(const Increment());
          await bloc.close();

          expect(exporter.spans, hasLength(1));
          final transition = exporter.spans.first.spanEvents!.first;
          expect(
            transition.attributes?.getString('event.value'),
            equals('[REDACTED_EVENT]'),
          );

          harness.clear();
          final omittingObserver = OtelBlocSignalObserver(
            tracer: tracer,
            eventRedactor: (bloc, event) => null,
          );
          BlocSignalObserver.observer = omittingObserver;

          final bloc2 = TestBloc()..add(const Increment());
          await bloc2.close();

          expect(exporter.spans, hasLength(1));
          final transition2 = exporter.spans.first.spanEvents!.first;
          expect(transition2.attributes?.getString('event.value'), isNull);
        },
      );

      test(
        '(Issue #422: F02) errorRedactor formats or omits error details on '
        'active and transient spans',
        () async {
          final customObserver = OtelBlocSignalObserver(
            tracer: tracer,
            errorRedactor: (bloc, error) => 'SafeError',
          );
          BlocSignalObserver.observer = customObserver;

          final bloc = TestBloc(initialState: -1);
          expect(() => bloc.add(const Increment()), throwsArgumentError);
          await bloc.close();

          expect(exporter.spans, hasLength(1));
          final activeSpan = exporter.spans.first;
          expect(activeSpan.statusDescription, equals('SafeError'));
          final exceptionEvent =
              activeSpan.spanEvents!.firstWhere((e) => e.name == 'exception');
          expect(
            exceptionEvent.attributes?.getString('exception.message'),
            equals('SafeError'),
          );

          harness.clear();
          final omittingObserver = OtelBlocSignalObserver(
            tracer: tracer,
            errorRedactor: (bloc, error) => null,
          );
          BlocSignalObserver.observer = omittingObserver;

          final bloc2 = TestBloc();
          omittingObserver.onError(
            bloc2,
            ArgumentError('Sensitive token=secret123'),
            StackTrace.empty,
          );
          await bloc2.close();

          expect(exporter.spans, hasLength(1));
          final transientSpan = exporter.spans.first;
          expect(transientSpan.statusDescription, isNull);
          final transientException = transientSpan.spanEvents!
              .firstWhere((e) => e.name == 'exception');
          expect(
            transientException.attributes?.getString('exception.message'),
            equals('[REDACTED]'),
          );
        },
      );

      test(
        '(Issue #422: F03) maxAttributeLength asserts > 0 and truncates '
        'state, event, error, and string metadata',
        () async {
          expect(
            () => OtelBlocSignalObserver(maxAttributeLength: 0),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => OtelBlocSignalObserver(maxAttributeLength: -5),
            throwsA(isA<AssertionError>()),
          );

          final cappedObserver = OtelBlocSignalObserver(
            tracer: tracer,
            maxAttributeLength: 5,
            stateRedactor: (bloc, state) => 'STATE_123456',
            eventRedactor: (bloc, event) => 'EVENT_123456',
            errorRedactor: (bloc, error) => 'ERROR_123456',
          );
          BlocSignalObserver.observer = cappedObserver;

          final bloc = TestBloc()..add(const Increment());
          cappedObserver.onTelemetry(
            bloc,
            'capped_meta',
            metadata: const {'msg': 'METADATA_123456'},
          );
          cappedObserver.onError(
            bloc,
            ArgumentError('RAW_ERROR'),
            StackTrace.empty,
          );
          await bloc.close();

          expect(exporter.spans, hasLength(3));
          final eventSpan = exporter.spans[0];
          expect(
            eventSpan.attributes.getString('state.value'),
            equals('STATE'),
          );
          final transitionEvent =
              eventSpan.spanEvents!.firstWhere((e) => e.name == 'transition');
          expect(
            transitionEvent.attributes?.getString('state.value'),
            equals('STATE'),
          );
          expect(
            transitionEvent.attributes?.getString('event.value'),
            equals('EVENT'),
          );

          final telemetrySpan = exporter.spans[1];
          expect(telemetrySpan.attributes.getString('msg'), equals('METAD'));

          final errorSpan = exporter.spans[2];
          expect(errorSpan.statusDescription, equals('ERROR'));
          final exceptionEvent =
              errorSpan.spanEvents!.firstWhere((e) => e.name == 'exception');
          expect(
            exceptionEvent.attributes?.getString('exception.message'),
            equals('ERROR'),
          );
        },
      );

      test(
        '(Issue #422: F04) onTelemetry normalizes and caps all metadata types',
        () async {
          final cappedObserver = OtelBlocSignalObserver(
            tracer: tracer,
            maxAttributeLength: 6,
          );
          BlocSignalObserver.observer = cappedObserver;

          final cubit = TestCubit();
          cappedObserver.onTelemetry(
            cubit,
            'normalized_meta',
            metadata: <String, dynamic>{
              'null_val': null,
              'bool_val': true,
              'int_val': 42,
              'double_val': 3.14,
              'str_val': 'long_string_value',
              'bool_list': <bool>[true, false],
              'int_list': <int>[1, 2, 3],
              'double_list': <double>[1.5, 2.5],
              'mixed_num_list': <num>[1, 2.5],
              'str_list': <String>['alpha_long', 'beta'],
              'mixed_list': <Object?>['x_long_item', 99, null],
              'set_val': <Object>{'set_item_long', 7},
              'map_val': <String, Object>{'key': 'val'},
              'custom_obj': const CustomMetadataObject('very_long_label'),
            },
          );

          expect(exporter.spans, hasLength(1));
          final attrs = exporter.spans.first.attributes;
          expect(attrs.getString('null_val'), equals('null'));
          expect(attrs.getBool('bool_val'), equals(true));
          expect(attrs.getInt('int_val'), equals(42));
          expect(attrs.getDouble('double_val'), equals(3.14));
          expect(attrs.getString('str_val'), equals('long_s'));
          expect(attrs.getBoolList('bool_list'), equals([true, false]));
          expect(attrs.getIntList('int_list'), equals([1, 2, 3]));
          expect(attrs.getDoubleList('double_list'), equals([1.5, 2.5]));
          expect(attrs.getDoubleList('mixed_num_list'), equals([1.0, 2.5]));
          expect(attrs.getStringList('str_list'), equals(['alpha_', 'beta']));
          expect(
            attrs.getStringList('mixed_list'),
            equals(['x_long', '99', 'null']),
          );
          expect(
            attrs.getStringList('set_val'),
            equals(['set_it', '7']),
          );
          expect(attrs.getString('map_val'), equals('{key: '));
          expect(attrs.getString('custom_obj'), equals('Custom'));

          await cubit.close();
        },
      );
    });
  });
}
