// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

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

  group('(Issue #475) OtelBlocSignalObserver Concurrency & Redaction', () {
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
      '(Issue #475) droppable() drops duplicate const event without closing '
      'in-flight handler span',
      () async {
        final gate = Completer<void>();
        final bloc = _DroppableConstBloc(gate);

        bloc
          ..add(const Increment())
          ..add(const Increment());

        await Future<void>.microtask(() {});

        // Only the dropped second event's span should be exported so far.
        expect(exporter.spans, hasLength(1));
        final droppedSpan = exporter.spans.first;
        expect(droppedSpan.attributes.getBool('bloc.contention'), isTrue);

        // Complete the first in-flight handler.
        gate.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(exporter.spans, hasLength(2));
        final firstSpan = exporter.spans[1];
        expect(firstSpan.status, equals(otel.SpanStatusCode.Ok));
        expect(firstSpan.attributes.getBool('bloc.contention'), isNull);
        expect(bloc.stateValue, equals(1));
      },
    );

    test(
      '(Issue #475) restartable() preemption does not close replacement span '
      'early when superseded handler finishes first',
      () async {
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final bloc = _RestartableMapBloc({1: gate1, 2: gate2});

        bloc.add(1);
        await Future<void>.microtask(() {});
        bloc.add(2);
        await Future<void>.microtask(() {});

        // Superseded span (1) should be closed with bloc.contention = true.
        expect(exporter.spans, hasLength(1));
        final preemptedSpan = exporter.spans.first;
        expect(preemptedSpan.attributes.getBool('bloc.contention'), isTrue);

        // Superseded handler completes first; replacement span (2) must stay
        // open!
        gate1.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        expect(exporter.spans, hasLength(1));

        // Now replacement handler completes.
        gate2.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(exporter.spans, hasLength(2));
        final replacementSpan = exporter.spans[1];
        expect(replacementSpan.status, equals(otel.SpanStatusCode.Ok));
        expect(replacementSpan.attributes.getBool('bloc.contention'), isNull);
        expect(bloc.stateValue, equals(2));
      },
    );

    test(
      '(Issue #475) onError closes only the failing event span and preserves '
      'unrelated concurrent spans',
      () async {
        final okGate = Completer<void>();
        final bloc = _ConcurrentErrorBloc(okGate);

        bloc
          ..add('ok')
          ..add('fail');

        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        // Only the failing event span should be closed with Error.
        expect(exporter.spans, hasLength(1));
        final errorSpan = exporter.spans.first;
        expect(errorSpan.status, equals(otel.SpanStatusCode.Error));

        // Complete the unrelated concurrent event; its span must close Ok.
        okGate.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(exporter.spans, hasLength(2));
        final okSpan = exporter.spans[1];
        expect(okSpan.status, equals(otel.SpanStatusCode.Ok));
        expect(bloc.stateValue, equals('ok'));
      },
    );

    test(
      '(Issue #475) chronological oldest-first eviction respects '
      'maxActiveSpans',
      () async {
        final cappedObserver = OtelBlocSignalObserver(
          tracer: tracer,
          maxActiveSpans: 2,
        );
        BlocSignalObserver.observer = cappedObserver;

        final gateA1 = Completer<void>();
        final gateB1 = Completer<void>();
        final gateA2 = Completer<void>();
        final bloc = _ConcurrentMapBloc({
          'A1': gateA1,
          'B1': gateB1,
          'A2': gateA2,
        });

        bloc.add('A1');
        await Future<void>.microtask(() {});
        bloc.add('B1');
        await Future<void>.microtask(() {});
        // Dispatching A2 exceeds maxActiveSpans=2 -> must evict A1 (oldest),
        // keeping B1 and A2 active.
        bloc.add('A2');
        await Future<void>.microtask(() {});

        expect(exporter.spans, hasLength(1));
        expect(
          exporter.spans.first.name,
          equals('_ConcurrentMapBloc.add(String)'),
        );

        // Completing B1 and A2 should close both with Ok.
        gateB1.complete();
        gateA2.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        gateA1.complete();
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(exporter.spans, hasLength(3));
        expect(exporter.spans[1].status, equals(otel.SpanStatusCode.Ok));
        expect(exporter.spans[2].status, equals(otel.SpanStatusCode.Ok));
      },
    );

    test(
      '(Issue #475) stackTraceRedactor and maxStackTraceLength sanitize '
      'recorded stack traces',
      () async {
        expect(
          () => OtelBlocSignalObserver(
            tracer: tracer,
            maxStackTraceLength: 0,
          ),
          throwsA(isA<AssertionError>()),
        );

        final redactedObserver = OtelBlocSignalObserver(
          tracer: tracer,
          stackTraceRedactor: (st) => 'REDACTED_STACK_TRACE_LONG_TEXT',
          maxStackTraceLength: 14,
        );
        BlocSignalObserver.observer = redactedObserver;

        final cubit = TestCubit();
        cubit.triggerError();

        expect(exporter.spans, hasLength(1));
        final exc = exporter.spans.first.spanEvents!
            .firstWhere((e) => e.name == 'exception');
        expect(
          exc.attributes?.getString('exception.stacktrace'),
          equals('REDACTED_STACK'),
        );

        // Empty redactor output omits exception.stacktrace.
        harness.clear();
        BlocSignalObserver.observer = OtelBlocSignalObserver(
          tracer: tracer,
          stackTraceRedactor: (st) => '',
        );
        cubit.triggerError();
        final excEmpty = exporter.spans.first.spanEvents!
            .firstWhere((e) => e.name == 'exception');
        expect(excEmpty.attributes?.getString('exception.stacktrace'), isNull);

        // maxStackTraceLength == null falls back to maxAttributeLength.
        harness.clear();
        BlocSignalObserver.observer = OtelBlocSignalObserver(
          tracer: tracer,
          stackTraceRedactor: (st) => 'FALLBACK_OBSERVER_STACK_TRACE',
          maxAttributeLength: 10,
        );
        cubit.triggerError();
        final excFallback = exporter.spans.first.spanEvents!
            .firstWhere((e) => e.name == 'exception');
        expect(
          excFallback.attributes?.getString('exception.stacktrace'),
          equals('FALLBACK_O'),
        );

        await cubit.close();
      },
    );

    test(
      '(Issue #475) un-zoned observer calls and zoned custom telemetry hit '
      'fallback and token paths cleanly',
      () async {
        final bloc = TestBloc();
        const event = Increment();

        // Un-zoned onEvent + onEventCompleted.
        observer.onEvent(bloc, event);
        observer.onEventCompleted(bloc, event);
        expect(exporter.spans, hasLength(1));
        expect(exporter.spans.first.status, equals(otel.SpanStatusCode.Ok));

        // Un-zoned onEvent + onError.
        harness.clear();
        observer.onEvent(bloc, event);
        observer.onError(bloc, Exception('Direct error'), StackTrace.current);
        expect(exporter.spans, hasLength(1));
        expect(exporter.spans.first.status, equals(otel.SpanStatusCode.Error));

        // Zoned custom telemetry inside active event span.
        harness.clear();
        final telemetryBloc = _CustomTelemetryBloc();
        telemetryBloc.add(const Increment());
        await Future<void>.microtask(() {});
        await telemetryBloc.close();
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        expect(
          exporter.spans.first.spanEvents
              ?.any((e) => e.name == 'custom_metric'),
          isTrue,
        );
      },
    );

    test(
      '(Issue #475) restartable() preemption on const identical events '
      'isolates replacement span in shared key queue',
      () async {
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final bloc = _RestartableConstQueueBloc([gate1, gate2]);

        bloc.add(const Increment());
        await Future<void>.microtask(() {});
        bloc.add(const Increment());
        await Future<void>.microtask(() {});

        // First const event span preempted with bloc.contention = true.
        expect(exporter.spans, hasLength(1));
        expect(
          exporter.spans.first.attributes.getBool('bloc.contention'),
          isTrue,
        );

        // Superseded handler completes first; replacement must stay open.
        gate1.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        expect(exporter.spans, hasLength(1));

        // Replacement completes cleanly.
        gate2.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(exporter.spans, hasLength(2));
        expect(exporter.spans[1].status, equals(otel.SpanStatusCode.Ok));
        expect(exporter.spans[1].attributes.getBool('bloc.contention'), isNull);
      },
    );

    test(
      '(Issue #475) zoned onError with absent token entry preserves sibling '
      'open span and isolates cross-container nested dispatches',
      () async {
        final siblingGate = Completer<void>();
        final nestedCubit = TestCubit();
        final outerBloc = _CrossContainerIsolationBloc(
          siblingGate: siblingGate,
          nestedCubit: nestedCubit,
          onSecondErrorInZone: (bloc) {
            // Invoke onError a second time inside the same dispatch zone after
            // its own span was already closed: must emit fallback error span
            // and MUST NOT close siblingGate's active span.
            observer.onError(
              bloc,
              Exception('Post-close zoned error'),
              StackTrace.current,
            );
          },
        );

        outerBloc
          ..add('hold')
          ..add('nested_and_double_error');

        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        // Expected closed spans so far:
        // 1) nestedCubit's error span (isolated from outerBloc's token)
        // 2) outerBloc's 'nested_and_double_error' span (from first error)
        // 3) outerBloc's fallback '.error' span (from second zoned error)
        // Meanwhile, outerBloc's 'hold' span MUST still be open!
        expect(exporter.spans, hasLength(3));
        expect(
          exporter.spans
              .any((s) => s.name == '_CrossContainerIsolationBloc.error'),
          isTrue,
        );

        // Complete the sibling 'hold' span and verify it closes Ok.
        siblingGate.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await outerBloc.close();
        await nestedCubit.close();

        expect(exporter.spans, hasLength(4));
        expect(exporter.spans[3].status, equals(otel.SpanStatusCode.Ok));
        expect(outerBloc.stateValue, equals('hold'));
      },
    );

    test(
      '(Issue #480: BLOCKER-2) OtelBlocSignalObserver marks only coalesced '
      'event span with bloc.contention while surviving event receives '
      'transition',
      () async {
        final debouncedBloc = _DebouncedOtelBloc();
        debouncedBloc.add('first');
        debouncedBloc.add('second');

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(debouncedBloc.stateValue, equals('second'));
        await debouncedBloc.close();

        final eventSpans = exporter.spans
            .where((s) => s.name.contains('add(String)'))
            .toList();
        expect(eventSpans, hasLength(2));

        final contentionSpans = eventSpans
            .where((s) => s.attributes.getBool('bloc.contention') == true)
            .toList();
        final normalSpans = eventSpans
            .where((s) => s.attributes.getBool('bloc.contention') != true)
            .toList();

        expect(contentionSpans, hasLength(1));
        expect(normalSpans, hasLength(1));
        expect(
          normalSpans.first.spanEvents!.any((e) => e.name == 'transition'),
          isTrue,
        );
        expect(
          contentionSpans.first.spanEvents!.any((e) => e.name == 'transition'),
          isFalse,
        );

        harness.clear();
        final throttledBloc = _TrailingThrottledOtelBloc();
        throttledBloc.add('lead');
        throttledBloc.add('mid');
        throttledBloc.add('trail');

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(throttledBloc.stateValue, equals('trail'));
        await throttledBloc.close();

        final tSpans = exporter.spans
            .where((s) => s.name.contains('add(String)'))
            .toList();
        expect(tSpans, hasLength(3));
        expect(
          tSpans.where((s) => s.attributes.getBool('bloc.contention') == true),
          hasLength(1),
        );
        final executedTSpans = tSpans
            .where((s) => s.attributes.getBool('bloc.contention') != true)
            .toList();
        expect(executedTSpans, hasLength(2));
        for (final span in executedTSpans) {
          expect(
            span.spanEvents!.any((e) => e.name == 'transition'),
            isTrue,
          );
        }
      },
    );
  });
}

class _DebouncedOtelBloc extends BlocSignal<String, String> {
  _DebouncedOtelBloc() : super(initialState: 'init') {
    on<String>(
      (event, emit) => emit(event),
      transformer: debounce(const Duration(milliseconds: 25)),
    );
  }
}

class _TrailingThrottledOtelBloc extends BlocSignal<String, String> {
  _TrailingThrottledOtelBloc() : super(initialState: 'init') {
    on<String>(
      (event, emit) => emit(event),
      transformer: throttle(const Duration(milliseconds: 30), trailing: true),
    );
  }
}

class _RestartableConstQueueBloc extends BlocSignal<Increment, int> {
  _RestartableConstQueueBloc(this.gates) : super(initialState: 0) {
    var index = 0;
    on<Increment>(
      (event, emit) async {
        final current = index++;
        await gates[current].future;
        emit(stateValue + 1);
      },
      transformer: restartable(),
    );
  }

  final List<Completer<void>> gates;
}

class _CrossContainerIsolationBloc extends BlocSignal<String, String> {
  _CrossContainerIsolationBloc({
    required this.siblingGate,
    required this.nestedCubit,
    required this.onSecondErrorInZone,
  }) : super(initialState: 'init') {
    on<String>((event, emit) async {
      if (event == 'hold') {
        await siblingGate.future;
        emit('hold');
        return;
      }
      // Trigger an error on an un-tokenized nested CubitSignal inside add().
      nestedCubit.triggerError();
      // Trigger first error on outerBloc (closes its dispatchToken span).
      emitError(Exception('First outer error'));
      // Trigger second error in the same dispatch zone (entry == null).
      onSecondErrorInZone(this);
    });
  }

  final Completer<void> siblingGate;
  final TestCubit nestedCubit;
  final void Function(BlocSignalBase<dynamic> bloc) onSecondErrorInZone;
}

class _CustomTelemetryBloc extends BlocSignal<Increment, int> {
  _CustomTelemetryBloc() : super(initialState: 0) {
    on<Increment>((event, emit) {
      emitTelemetry('custom_metric', event: event, metadata: {'k': 'v'});
      emit(stateValue + 1);
    });
  }
}

class _DroppableConstBloc extends BlocSignal<Increment, int> {
  _DroppableConstBloc(this.gate) : super(initialState: 0) {
    on<Increment>(
      (event, emit) async {
        await gate.future;
        emit(stateValue + 1);
      },
      transformer: droppable(),
    );
  }

  final Completer<void> gate;
}

class _RestartableMapBloc extends BlocSignal<int, int> {
  _RestartableMapBloc(this.gates) : super(initialState: 0) {
    on<int>(
      (event, emit) async {
        await gates[event]!.future;
        emit(event);
      },
      transformer: restartable(),
    );
  }

  final Map<int, Completer<void>> gates;
}

class _ConcurrentErrorBloc extends BlocSignal<String, String> {
  _ConcurrentErrorBloc(this.okGate) : super(initialState: 'init') {
    on<String>(
      (event, emit) async {
        if (event == 'fail') {
          throw Exception('Boom');
        }
        await okGate.future;
        emit(event);
      },
    );
  }

  final Completer<void> okGate;
}

class _ConcurrentMapBloc extends BlocSignal<String, String> {
  _ConcurrentMapBloc(this.gates) : super(initialState: 'init') {
    on<String>(
      (event, emit) async {
        await gates[event]!.future;
        emit(event);
      },
    );
  }

  final Map<String, Completer<void>> gates;
}
