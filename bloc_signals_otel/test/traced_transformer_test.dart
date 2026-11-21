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

sealed class TraceTestEvent {}

final class DoWorkEvent extends TraceTestEvent {
  DoWorkEvent(this.payload);
  final String payload;
}

final class FailingEvent extends TraceTestEvent {}

class TracedTestBloc extends BlocSignal<TraceTestEvent, String> {
  TracedTestBloc({
    required EventTransformer<DoWorkEvent, String> workTransformer,
    otel.APITracer? tracer,
    String? customSpanName,
  }) : super(initialState: 'idle') {
    on<DoWorkEvent>(
      (event, emit) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        emit('done:${event.payload}');
      },
      blocTransformer: traced(
        workTransformer,
        tracer: tracer,
        spanName: customSpanName,
      ),
    );

    on<FailingEvent>(
      (event, emit) => throw StateError('Handler failure'),
      blocTransformer: traced(
        (event, handler, emit) => handler(event, emit),
        tracer: tracer,
      ),
    );
  }
}

void main() {
  group('(Issue #352) traced Transformer Decorator Tests', () {
    late TestHarness harness;
    late InMemorySpanExporter exporter;
    late otel.APITracer tracer;

    setUpAll(() async {
      harness = await maybeInitializeOtelForTest(
        serviceName: 'traced_transformer_test',
      );
      exporter = harness.spans;
    });

    setUp(() {
      harness.clear();
      tracer = OTel.tracerProvider().getTracer('test_tracer');
    });

    test(
      '(Issue #352) uses default global OTelAPI tracerProvider if none is '
      'provided',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
        );

        bloc.add(DoWorkEvent('default_tracer'));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(bloc.stateValue, equals('done:default_tracer'));
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TracedTestBloc.DoWorkEvent'));
        expect(span.instrumentationScope.name, equals('bloc_signals_otel'));
      },
    );

    test(
      '(Issue #352) instruments transformer execution and records attributes',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        bloc.add(DoWorkEvent('task1'));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(bloc.stateValue, equals('done:task1'));
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TracedTestBloc.DoWorkEvent'));
        expect(span.status, equals(otel.SpanStatusCode.Ok));
        expect(
          span.attributes.getString('bloc.type'),
          equals('TracedTestBloc'),
        );
        expect(
          span.attributes.getString('event.type'),
          equals('DoWorkEvent'),
        );
      },
    );

    test('(Issue #352) supports custom span name override', () async {
      final bloc = TracedTestBloc(
        workTransformer: sequential(),
        tracer: tracer,
        customSpanName: 'custom.work.span',
      );

      bloc.add(DoWorkEvent('task2'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.stateValue, equals('done:task2'));
      await bloc.close();

      expect(exporter.spans, hasLength(1));
      final span = exporter.spans.first;
      expect(span.name, equals('custom.work.span'));
      expect(span.status, equals(otel.SpanStatusCode.Ok));
    });

    test(
      '(Issue #352) records exception and sets status to error on handler '
      'failure',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        Object? capturedError;
        runZonedGuarded(
          () => bloc.add(FailingEvent()),
          (error, stack) => capturedError = error,
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(capturedError, isA<StateError>());
        await bloc.close();

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TracedTestBloc.FailingEvent'));
        expect(span.status, equals(otel.SpanStatusCode.Error));
        expect(span.statusDescription, contains('Handler failure'));
      },
    );

    test(
      '(Issue #352) tracedBloc decorates existing BlocEventTransformer',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );
        // Verify tracedBloc decorator wraps contextual transformer
        final contextual = tracedBloc<DoWorkEvent, String>(
          (b, event, handler, emit) {
            emitContainerTelemetry(b, 'custom_telemetry');
            return handler(event, emit);
          },
          tracer: tracer,
        );

        var handlerInvoked = false;
        final res = contextual(
          bloc,
          DoWorkEvent('direct'),
          (e, emit) {
            handlerInvoked = true;
            emit('handled');
          },
          bloc.emit,
        );
        if (res is Future) await res;

        expect(handlerInvoked, isTrue);
        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.name, equals('TracedTestBloc.DoWorkEvent'));
        expect(span.status, equals(otel.SpanStatusCode.Ok));

        await bloc.close();
      },
    );

    test(
      '(Issue #352) records exception when async handler fails in traced',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        final tracedTx = traced<DoWorkEvent, String>(
          (event, handler, emit) => handler(event, emit),
          tracer: tracer,
        );

        Object? captured;
        try {
          final res = tracedTx(
            bloc,
            DoWorkEvent('async_fail'),
            (e, emit) async {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              throw StateError('Async handler failure');
            },
            bloc.emit,
          );
          if (res is Future) await res;
        } on Object catch (e) {
          captured = e;
        }

        expect(captured, isA<StateError>());
        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.status, equals(otel.SpanStatusCode.Error));
        expect(span.statusDescription, contains('Async handler failure'));

        await bloc.close();
      },
    );

    test(
      '(Issue #352) records exception when async transformer itself fails',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        final tracedTx = tracedBloc<DoWorkEvent, String>(
          (b, event, handler, emit) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            throw StateError('Transformer async error');
          },
          tracer: tracer,
        );

        Object? captured;
        try {
          final res = tracedTx(
            bloc,
            DoWorkEvent('tx_fail'),
            (e, emit) {},
            bloc.emit,
          );
          if (res is Future) await res;
        } on Object catch (e) {
          captured = e;
        }

        expect(captured, isA<StateError>());
        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.status, equals(otel.SpanStatusCode.Error));
        expect(span.statusDescription, contains('Transformer async error'));

        await bloc.close();
      },
    );

    test(
      '(Issue #352) records exception exactly once without duplicate exception '
      'events',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        final tracedTx = traced<DoWorkEvent, String>(
          (event, handler, emit) => handler(event, emit),
          tracer: tracer,
        );

        try {
          final res = tracedTx(
            bloc,
            DoWorkEvent('single_error'),
            (e, emit) async {
              throw StateError('Single error failure');
            },
            bloc.emit,
          );
          if (res is Future) await res;
        } on Object catch (_) {}

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        final exceptionEvents =
            span.spanEvents?.where((e) => e.name == 'exception').toList() ?? [];
        expect(exceptionEvents, hasLength(1));

        await bloc.close();
      },
    );

    test(
      '(Issue #352) keeps span open for async transformers returning a Future',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        final asyncTx = tracedBloc<DoWorkEvent, String>(
          (b, event, handler, emit) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await handler(event, emit);
          },
          tracer: tracer,
        );

        final future = asyncTx(
          bloc,
          DoWorkEvent('deferred'),
          (e, emit) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            emit('deferred_done');
          },
          bloc.emit,
        );

        // While asyncTx is in flight, span must NOT be exported yet!
        expect(exporter.spans, isEmpty);

        await future;

        expect(exporter.spans, hasLength(1));
        final span = exporter.spans.first;
        expect(span.status, equals(otel.SpanStatusCode.Ok));

        await bloc.close();
      },
    );

    test(
      '(Issue #310: F12, Issue #352) ends span immediately for dropped events '
      'without leaking',
      () async {
        final bloc = TracedTestBloc(
          workTransformer: droppable(),
          tracer: tracer,
        );

        // First event starts work and takes 10ms.
        bloc.add(DoWorkEvent('first'));
        // Second event added immediately while first is in flight;
        // droppable drops it.
        bloc.add(DoWorkEvent('dropped'));

        // The dropped event returned synchronously and its span must be
        // completed.
        expect(exporter.spans, hasLength(1));
        final droppedSpan = exporter.spans.first;
        expect(droppedSpan.status, equals(otel.SpanStatusCode.Ok));

        await Future<void>.delayed(const Duration(milliseconds: 25));
        // Now the first event has also finished.
        expect(exporter.spans, hasLength(2));

        await bloc.close();
      },
    );

    group('(Issue #422) Error Redaction and Attribute Length Caps', () {
      test(
        '(Issue #422: F02) traced and tracedBloc apply errorRedactor for '
        'custom strings and null omission',
        () async {
          final bloc = TracedTestBloc(
            workTransformer: sequential(),
            tracer: tracer,
          );

          final redactedTx = traced<DoWorkEvent, String>(
            (event, handler, emit) => handler(event, emit),
            tracer: tracer,
            errorRedactor: (b, error) => 'SanitizedError',
          );

          Object? captured;
          try {
            final res = redactedTx(
              bloc,
              DoWorkEvent('fail'),
              (e, emit) => throw StateError('Secret stack detail'),
              bloc.emit,
            );
            if (res is Future) await res;
          } on Object catch (e) {
            captured = e;
          }

          expect(captured, isA<StateError>());
          expect(exporter.spans, hasLength(1));
          final span1 = exporter.spans.first;
          expect(span1.statusDescription, equals('SanitizedError'));
          final exc1 =
              span1.spanEvents!.firstWhere((e) => e.name == 'exception');
          expect(
            exc1.attributes?.getString('exception.message'),
            equals('SanitizedError'),
          );

          harness.clear();
          final omittingTx = tracedBloc<DoWorkEvent, String>(
            (b, event, handler, emit) => handler(event, emit),
            tracer: tracer,
            errorRedactor: (b, error) => null,
          );

          try {
            final res = omittingTx(
              bloc,
              DoWorkEvent('fail2'),
              (e, emit) => throw StateError('Secret token=abc'),
              bloc.emit,
            );
            if (res is Future) await res;
          } on Object catch (_) {}

          expect(exporter.spans, hasLength(1));
          final span2 = exporter.spans.first;
          expect(span2.statusDescription, isNull);
          final exc2 =
              span2.spanEvents!.firstWhere((e) => e.name == 'exception');
          expect(
            exc2.attributes?.getString('exception.message'),
            equals('[REDACTED]'),
          );

          await bloc.close();
        },
      );

      test(
        '(Issue #422: F03) traced and tracedBloc assert maxAttributeLength > 0 '
        'and truncate error messages',
        () async {
          expect(
            () => traced<DoWorkEvent, String>(
              sequential(),
              maxAttributeLength: 0,
            ),
            throwsA(isA<AssertionError>()),
          );
          expect(
            () => tracedBloc<DoWorkEvent, String>(
              (b, event, handler, emit) => handler(event, emit),
              maxAttributeLength: -1,
            ),
            throwsA(isA<AssertionError>()),
          );

          final bloc = TracedTestBloc(
            workTransformer: sequential(),
            tracer: tracer,
          );

          final cappedTx = tracedBloc<DoWorkEvent, String>(
            (b, event, handler, emit) => handler(event, emit),
            tracer: tracer,
            errorRedactor: (b, error) => 'LONG_ERROR_MESSAGE',
            maxAttributeLength: 4,
          );

          try {
            final res = cappedTx(
              bloc,
              DoWorkEvent('fail_cap'),
              (e, emit) => throw StateError('raw'),
              bloc.emit,
            );
            if (res is Future) await res;
          } on Object catch (_) {}

          expect(exporter.spans, hasLength(1));
          final span = exporter.spans.first;
          expect(span.statusDescription, equals('LONG'));
          final exc = span.spanEvents!.firstWhere((e) => e.name == 'exception');
          expect(
            exc.attributes?.getString('exception.message'),
            equals('LONG'),
          );

          await bloc.close();
        },
      );
    });
  });

  group('(Issue #475) tracedBloc Context.current, Contention, & StackTrace',
      () {
    late TestHarness harness;
    late InMemorySpanExporter exporter;
    late otel.APITracer tracer;

    setUpAll(() async {
      harness = await maybeInitializeOtelForTest(
        serviceName: 'traced_transformer_test',
      );
      exporter = harness.spans;
    });

    setUp(() {
      harness.clear();
      tracer = OTel.tracerProvider().getTracer('test_tracer');
    });

    test(
      '(Issue #475) otel.Context.current.span resolves to active event span '
      'inside sync & async handlers',
      () async {
        final observedSyncSpans = <otel.APISpan>[];
        final observedAsyncSpans = <otel.APISpan>[];
        final asyncGate = Completer<void>();

        final bloc = _ContextAwareTracedBloc(
          tracer: tracer,
          asyncGate: asyncGate,
          onSync: observedSyncSpans.add,
          onAsync: observedAsyncSpans.add,
        );

        bloc.add(_SyncCtxEvent());
        bloc.add(_AsyncCtxEvent());
        await Future<void>.microtask(() {});
        asyncGate.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(observedSyncSpans, hasLength(1));
        expect(observedAsyncSpans, hasLength(1));

        // Verify child spans started inside handlers inherit parentSpanId.
        final childSpans =
            exporter.spans.where((s) => s.name.startsWith('child.')).toList();
        final parentSpans =
            exporter.spans.where((s) => !s.name.startsWith('child.')).toList();

        expect(parentSpans, hasLength(2));
        expect(childSpans, hasLength(2));

        final syncParent =
            parentSpans.firstWhere((s) => s.name.contains('_SyncCtxEvent'));
        final syncChild = childSpans.firstWhere((s) => s.name == 'child.sync');
        expect(
          syncChild.parentSpanContext?.spanId,
          equals(syncParent.spanContext.spanId),
        );

        final asyncParent =
            parentSpans.firstWhere((s) => s.name.contains('_AsyncCtxEvent'));
        final asyncChild =
            childSpans.firstWhere((s) => s.name == 'child.async');
        expect(
          asyncChild.parentSpanContext?.spanId,
          equals(asyncParent.spanContext.spanId),
        );
      },
    );

    test(
      '(Issue #475) dropped or bypassed invocations set bloc.contention = true',
      () async {
        final gate = Completer<void>();
        final bloc = _DroppableTracedBloc(gate: gate, tracer: tracer);

        bloc
          ..add(DoWorkEvent('first'))
          ..add(DoWorkEvent('second'));

        await Future<void>.microtask(() {});

        // Dropped second event should have ended immediately with contention.
        expect(exporter.spans, hasLength(1));
        final droppedSpan = exporter.spans.first;
        expect(droppedSpan.attributes.getBool('bloc.contention'), isTrue);

        gate.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        await bloc.close();

        expect(exporter.spans, hasLength(2));
        final firstSpan = exporter.spans[1];
        expect(firstSpan.attributes.getBool('bloc.contention'), isNull);
        expect(firstSpan.status, equals(otel.SpanStatusCode.Ok));
      },
    );

    test(
      '(Issue #475) stackTraceRedactor and maxStackTraceLength work on traced '
      'and tracedBloc',
      () async {
        expect(
          () => traced<DoWorkEvent, String>(
            sequential(),
            maxStackTraceLength: 0,
          ),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => tracedBloc<DoWorkEvent, String>(
            (b, event, handler, emit) => handler(event, emit),
            maxStackTraceLength: -1,
          ),
          throwsA(isA<AssertionError>()),
        );

        final bloc = TracedTestBloc(
          workTransformer: sequential(),
          tracer: tracer,
        );

        final redactedTx = traced<DoWorkEvent, String>(
          (event, handler, emit) => handler(event, emit),
          tracer: tracer,
          stackTraceRedactor: (st) => 'TRACED_REDACTED_STACK_TRACE',
          maxStackTraceLength: 15,
        );

        try {
          final res = redactedTx(
            bloc,
            DoWorkEvent('fail_st'),
            (e, emit) => throw StateError('raw'),
            bloc.emit,
          );
          if (res is Future) await res;
        } on Object catch (_) {}

        expect(exporter.spans, hasLength(1));
        final exc = exporter.spans.first.spanEvents!
            .firstWhere((e) => e.name == 'exception');
        expect(
          exc.attributes?.getString('exception.stacktrace'),
          equals('TRACED_REDACTED'),
        );

        // Empty redactor output omits exception.stacktrace.
        harness.clear();
        final emptyRedactedTx = tracedBloc<DoWorkEvent, String>(
          (b, event, handler, emit) => handler(event, emit),
          tracer: tracer,
          stackTraceRedactor: (st) => '',
        );
        try {
          final res = emptyRedactedTx(
            bloc,
            DoWorkEvent('fail_empty'),
            (e, emit) => throw StateError('raw'),
            bloc.emit,
          );
          if (res is Future) await res;
        } on Object catch (_) {}
        final excEmpty = exporter.spans.first.spanEvents!
            .firstWhere((e) => e.name == 'exception');
        expect(excEmpty.attributes?.getString('exception.stacktrace'), isNull);

        // maxStackTraceLength == null falls back to maxAttributeLength.
        harness.clear();
        final fallbackCapTx = traced<DoWorkEvent, String>(
          (event, handler, emit) => handler(event, emit),
          tracer: tracer,
          stackTraceRedactor: (st) => 'FALLBACK_STACK_TRACE_CONTENT',
          maxAttributeLength: 8,
        );
        try {
          final res = fallbackCapTx(
            bloc,
            DoWorkEvent('fail_fallback'),
            (e, emit) => throw StateError('raw'),
            bloc.emit,
          );
          if (res is Future) await res;
        } on Object catch (_) {}
        final excFallback = exporter.spans.first.spanEvents!
            .firstWhere((e) => e.name == 'exception');
        expect(
          excFallback.attributes?.getString('exception.stacktrace'),
          equals('FALLBACK'),
        );

        await bloc.close();
      },
    );
  });
}

final class _SyncCtxEvent extends TraceTestEvent {}

final class _AsyncCtxEvent extends TraceTestEvent {}

class _ContextAwareTracedBloc extends BlocSignal<TraceTestEvent, String> {
  _ContextAwareTracedBloc({
    required otel.APITracer tracer,
    required Completer<void> asyncGate,
    required void Function(otel.APISpan span) onSync,
    required void Function(otel.APISpan span) onAsync,
  }) : super(initialState: 'idle') {
    on<_SyncCtxEvent>(
      (event, emit) {
        final current = otel.Context.current.span;
        if (current != null) onSync(current);
        tracer.startSpan('child.sync').end();
        emit('sync');
      },
      blocTransformer: traced(
        (event, handler, emit) => handler(event, emit),
        tracer: tracer,
      ),
    );

    on<_AsyncCtxEvent>(
      (event, emit) async {
        await asyncGate.future;
        final current = otel.Context.current.span;
        if (current != null) onAsync(current);
        tracer.startSpan('child.async').end();
        emit('async');
      },
      blocTransformer: traced(
        sequential(),
        tracer: tracer,
      ),
    );
  }
}

class _DroppableTracedBloc extends BlocSignal<TraceTestEvent, String> {
  _DroppableTracedBloc({
    required Completer<void> gate,
    required otel.APITracer tracer,
  }) : super(initialState: 'idle') {
    on<DoWorkEvent>(
      (event, emit) async {
        await gate.future;
        emit('done:${event.payload}');
      },
      blocTransformer: traced(
        droppable(),
        tracer: tracer,
      ),
    );
  }
}
