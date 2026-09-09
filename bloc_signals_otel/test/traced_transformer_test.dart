// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:opentelemetry/api.dart' as otel;
import 'package:opentelemetry/sdk.dart' as otel_sdk;
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
    otel.Tracer? tracer,
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
  group('traced Transformer Decorator Tests', () {
    late InMemorySpanExporter exporter;
    late otel_sdk.TracerProviderBase tracerProvider;
    late otel.Tracer tracer;

    setUp(() {
      exporter = InMemorySpanExporter();
      tracerProvider = otel_sdk.TracerProviderBase(
        processors: [otel_sdk.SimpleSpanProcessor(exporter)],
      );
      tracer = tracerProvider.getTracer('test_tracer');
    });

    tearDown(() {
      tracerProvider.shutdown();
    });

    test('uses default global tracer if none is provided', () async {
      final bloc = TracedTestBloc(
        workTransformer: sequential(),
      );

      bloc.add(DoWorkEvent('default_tracer'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.stateValue, equals('done:default_tracer'));
      await bloc.close();
    });

    test('instruments transformer execution and records attributes', () async {
      final bloc = TracedTestBloc(
        workTransformer: sequential(),
        tracer: tracer,
      );

      bloc.add(DoWorkEvent('task1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.stateValue, equals('done:task1'));
      await bloc.close();

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TracedTestBloc.DoWorkEvent'));
      expect(span.status.code, equals(otel.StatusCode.ok));
      expect(span.attributes.get('bloc.type'), equals('TracedTestBloc'));
      expect(span.attributes.get('event.type'), equals('DoWorkEvent'));
    });

    test('supports custom span name override', () async {
      final bloc = TracedTestBloc(
        workTransformer: sequential(),
        tracer: tracer,
        customSpanName: 'custom.work.span',
      );

      bloc.add(DoWorkEvent('task2'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.stateValue, equals('done:task2'));
      await bloc.close();

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('custom.work.span'));
      expect(span.status.code, equals(otel.StatusCode.ok));
    });

    test('records exception and sets status to error on handler failure',
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

      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TracedTestBloc.FailingEvent'));
      expect(span.status.code, equals(otel.StatusCode.error));
      expect(span.status.description, contains('Handler failure'));
    });

    test('tracedBloc decorates existing BlocEventTransformer', () async {
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
      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.name, equals('TracedTestBloc.DoWorkEvent'));
      expect(span.status.code, equals(otel.StatusCode.ok));

      await bloc.close();
    });

    test('records exception when async handler fails in traced', () async {
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
      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.status.code, equals(otel.StatusCode.error));
      expect(span.status.description, contains('Async handler failure'));

      await bloc.close();
    });

    test('records exception when async transformer itself fails', () async {
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
      expect(exporter.exportedSpans, hasLength(1));
      final span = exporter.exportedSpans.first;
      expect(span.status.code, equals(otel.StatusCode.error));
      expect(span.status.description, contains('Transformer async error'));

      await bloc.close();
    });
  });
}
