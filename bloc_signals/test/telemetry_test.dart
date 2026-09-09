// Cascade invocations are ignored to keep test setup clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

sealed class CounterEvent {}

final class Increment extends CounterEvent {}

final class SlowIncrement extends CounterEvent {
  SlowIncrement(this.delayMs, this.value);
  final int delayMs;
  final int value;
}

class TelemetryCounterCubit extends CubitSignal<int> {
  TelemetryCounterCubit({super.initialState = 0});

  void incrementWithTelemetry() {
    emitTelemetry('counter_incremented', metadata: {'current': stateValue});
    emit(stateValue + 1);
  }

  void triggerEmitError() {
    emitError(Exception('Failed to compute state'));
  }

  void triggerAddError() {
    addError(Exception('Legacy error'));
  }

  Object get publicZoneBlocKey => zoneBlocKey;
}

class TelemetryCounterBloc extends BlocSignal<CounterEvent, int> {
  TelemetryCounterBloc({super.initialState = 0}) {
    on<Increment>((event, emit) {
      emitTelemetry('increment_received', event: event);
      emit(stateValue + 1);
    });
  }
}

class _DroppableTelemetryBloc extends BlocSignal<CounterEvent, int> {
  _DroppableTelemetryBloc() : super(initialState: 0) {
    on<SlowIncrement>(
      (event, emit) async {
        await Future<void>.delayed(Duration(milliseconds: event.delayMs));
        emit(stateValue + event.value);
      },
      transformer: droppable(),
    );
  }
}

class _SequentialTelemetryBloc extends BlocSignal<CounterEvent, int> {
  _SequentialTelemetryBloc() : super(initialState: 0) {
    on<SlowIncrement>(
      (event, emit) async {
        await Future<void>.delayed(Duration(milliseconds: event.delayMs));
        emit(stateValue + event.value);
      },
      transformer: sequential(),
    );
  }
}

class _RestartableTelemetryBloc extends BlocSignal<CounterEvent, int> {
  _RestartableTelemetryBloc() : super(initialState: 0) {
    on<SlowIncrement>(
      (event, emit) async {
        await Future<void>.delayed(Duration(milliseconds: event.delayMs));
        emit(stateValue + event.value);
      },
      transformer: restartable(),
    );
  }
}

class _RecordingObserver extends BlocSignalObserver {
  final telemetryLogs = <({
    BlocSignalBase<dynamic> bloc,
    String name,
    Object? event,
    Map<String, dynamic>? metadata,
  })>[];

  final errorLogs = <({
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  })>[];

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    telemetryLogs.add(
      (
        bloc: bloc,
        name: name,
        event: event,
        metadata: metadata != null ? Map<String, dynamic>.from(metadata) : null,
      ),
    );
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errorLogs.add((bloc: bloc, error: error, stackTrace: stackTrace));
  }
}

class _FaultyObserver extends BlocSignalObserver {
  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    throw StateError('Observer pipeline exploded');
  }
}

void main() {
  group('Diagnostic Triad & Telemetry on BlocSignalBase', () {
    late _RecordingObserver observer;

    setUp(() {
      observer = _RecordingObserver();
      BlocSignalObserver.observer = observer;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
    });

    test('CubitSignal emits telemetry to global observer', () {
      final cubit = TelemetryCounterCubit();
      cubit.incrementWithTelemetry();

      expect(cubit.stateValue, equals(1));
      expect(observer.telemetryLogs, hasLength(1));
      final log = observer.telemetryLogs.first;
      expect(log.bloc, equals(cubit));
      expect(log.name, equals('counter_incremented'));
      expect(log.metadata, equals({'current': 0}));
    });

    test('emitError forwards to onError and observer', () {
      final cubit = TelemetryCounterCubit();
      cubit.triggerEmitError();

      expect(observer.errorLogs, hasLength(1));
      expect(
        observer.errorLogs.first.error.toString(),
        contains('Failed to compute state'),
      );
    });

    test('addError maintains backward compatibility as alias to emitError', () {
      final cubit = TelemetryCounterCubit();
      cubit.triggerAddError();

      expect(observer.errorLogs, hasLength(1));
      expect(
        observer.errorLogs.first.error.toString(),
        contains('Legacy error'),
      );
    });

    test('BlocSignal emits telemetry with event context', () {
      final bloc = TelemetryCounterBloc();
      bloc.add(Increment());

      expect(bloc.stateValue, equals(1));
      expect(observer.telemetryLogs, hasLength(1));
      final log = observer.telemetryLogs.first;
      expect(log.name, equals('increment_received'));
      expect(log.event, isA<Increment>());
    });

    test('observer exceptions inside onTelemetry are isolated to onError', () {
      final faulty = _FaultyObserver();
      BlocSignalObserver.observer = faulty;

      final cubit = TelemetryCounterCubit();
      // Should not throw exception to caller:
      expect(cubit.incrementWithTelemetry, returnsNormally);
      expect(cubit.stateValue, equals(1));
    });

    test('short-circuits telemetry immediately when observer is null', () {
      BlocSignalObserver.observer = null;
      final cubit = TelemetryCounterCubit();
      expect(cubit.incrementWithTelemetry, returnsNormally);
    });
  });

  group('Built-in Concurrency Transformer Telemetry', () {
    late _RecordingObserver observer;

    setUp(() {
      observer = _RecordingObserver();
      BlocSignalObserver.observer = observer;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
    });

    test('droppable emits event_dropped telemetry when busy', () async {
      final bloc = _DroppableTelemetryBloc();
      bloc.add(SlowIncrement(50, 10));
      bloc.add(SlowIncrement(10, 20));

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(bloc.stateValue, equals(10));

      final droppedLogs = observer.telemetryLogs
          .where((l) => l.name == BlocTelemetryKeys.eventDropped)
          .toList();

      expect(droppedLogs, hasLength(1));
      expect(
        droppedLogs.first.metadata,
        equals(
          {
            'transformer': 'droppable',
            'reason': 'in_flight',
          },
        ),
      );
      expect(droppedLogs.first.event, isA<SlowIncrement>());
    });

    test('sequential emits event_queued telemetry with queue wait time',
        () async {
      final bloc = _SequentialTelemetryBloc();
      bloc.add(SlowIncrement(30, 1));
      bloc.add(SlowIncrement(10, 2));

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(bloc.stateValue, equals(3));

      final queuedLogs = observer.telemetryLogs
          .where((l) => l.name == BlocTelemetryKeys.eventQueued)
          .toList();

      expect(queuedLogs, hasLength(1));
      expect(queuedLogs.first.metadata?['transformer'], equals('sequential'));
      expect(queuedLogs.first.metadata?['queue_wait_ms'], isA<int>());
    });

    test('zoneBlocKey exposes ambientZoneBlocKey', () {
      final cubit = TelemetryCounterCubit();
      expect(
        cubit.publicZoneBlocKey,
        equals(BlocSignalBase.ambientZoneBlocKey),
      );
    });

    test('restartable emits task_preempted telemetry on supersede', () async {
      final bloc = _RestartableTelemetryBloc();
      bloc.add(SlowIncrement(50, 100));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(SlowIncrement(10, 200));

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(bloc.stateValue, equals(200));

      final preemptedLogs = observer.telemetryLogs
          .where((l) => l.name == BlocTelemetryKeys.taskPreempted)
          .toList();

      expect(preemptedLogs, hasLength(1));
      final preemptedEvent = preemptedLogs.first.event! as SlowIncrement;
      expect(preemptedEvent.value, equals(100));
      expect(
        preemptedLogs.first.metadata,
        equals(
          {
            'transformer': 'restartable',
            'reason': 'superseded',
          },
        ),
      );
    });
  });
}
