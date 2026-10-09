// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

sealed class CounterEvent {}

class FastIncrement extends CounterEvent {}

class DelayedIncrement extends CounterEvent {
  DelayedIncrement(this.durationMs, this.value);
  final int durationMs;
  final int value;
}

void main() {
  group('Mutex', () {
    test('ensures mutual exclusion and FIFO queue execution', () async {
      final mutex = Mutex();
      final executionOrder = <int>[];

      final future1 = mutex.protect(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        executionOrder.add(1);
      });

      final future2 = mutex.protect(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        executionOrder.add(2);
      });

      expect(mutex.isLocked, isTrue);
      await Future.wait([future1, future2]);
      expect(executionOrder, equals([1, 2]));
      expect(mutex.isLocked, isFalse);
    });
  });

  group('Event Transformers', () {
    test('droppable ignores events while a handler is active', () async {
      final bloc = _DroppableBloc();
      expect(bloc.stateValue, equals(0));

      bloc.add(DelayedIncrement(50, 10));
      bloc.add(DelayedIncrement(10, 20));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(bloc.stateValue, equals(10));
    });

    test('sequential processes events sequentially in order', () async {
      final bloc = _SequentialBloc();

      bloc.add(DelayedIncrement(50, 1));
      bloc.add(DelayedIncrement(10, 2));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bloc.history, equals([1, 2]));
    });

    test('restartable cancels previous incomplete execution', () async {
      final bloc = _RestartableBloc();

      bloc.add(DelayedIncrement(50, 100));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(DelayedIncrement(10, 200));

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(bloc.stateValue, equals(200));
    });

    test(
      'does not emit false task_preempted telemetry when active handler '
      'completes before superseded slow handler (Issue #324: R10)',
      () async {
        final previousObserver = BlocSignalObserver.observer;
        final observer = _TelemetryRecordingObserver();
        BlocSignalObserver.observer = observer;
        addTearDown(() {
          BlocSignalObserver.observer = previousObserver;
        });

        final completer1 = Completer<void>();
        final completer2 = Completer<void>();
        final completer3 = Completer<void>();

        final bloc = _ControlledRestartableBloc({
          1: completer1.future,
          2: completer2.future,
          3: completer3.future,
        });
        addTearDown(bloc.close);

        // Event 1 (slow) starts and remains in flight.
        bloc.add(DelayedIncrement(0, 1));
        await Future<void>.microtask(() {});

        // Event 2 (fast) supersedes Event 1 and emits task_preempted for
        // Event 1.
        bloc.add(DelayedIncrement(0, 2));
        await Future<void>.microtask(() {});

        // Event 2 finishes while Event 1's future is still pending.
        completer2.complete();
        await Future<void>.microtask(() {});
        expect(bloc.stateValue, equals(2));

        // Event 3 arrives while Event 1 is still pending, but Event 2 (the
        // active execution) has already finished. Must NOT emit task_preempted!
        bloc.add(DelayedIncrement(0, 3));
        await Future<void>.microtask(() {});

        completer3.complete();
        completer1.complete();
        await Future<void>.microtask(() {});
        expect(bloc.stateValue, equals(3));

        final preemptedEvents = observer.preemptedEvents
            .whereType<DelayedIncrement>()
            .map((e) => e.value)
            .toList();
        expect(preemptedEvents, equals([1]));
      },
    );
  });
}

class _DroppableBloc extends BlocSignal<CounterEvent, int> {
  _DroppableBloc() : super(initialState: 0) {
    on<DelayedIncrement>(
      (event, emit) async {
        await Future<void>.delayed(Duration(milliseconds: event.durationMs));
        emit(stateValue + event.value);
      },
      transformer: droppable(),
    );
  }
}

class _SequentialBloc extends BlocSignal<CounterEvent, int> {
  _SequentialBloc() : super(initialState: 0) {
    on<DelayedIncrement>(
      (event, emit) async {
        await Future<void>.delayed(Duration(milliseconds: event.durationMs));
        history.add(event.value);
        emit(stateValue + event.value);
      },
      transformer: sequential(),
    );
  }

  final List<int> history = [];
}

class _RestartableBloc extends BlocSignal<CounterEvent, int> {
  _RestartableBloc() : super(initialState: 0) {
    on<DelayedIncrement>(
      (event, emit) async {
        await Future<void>.delayed(Duration(milliseconds: event.durationMs));
        emit(event.value);
      },
      transformer: restartable(),
    );
  }
}

class _ControlledRestartableBloc extends BlocSignal<CounterEvent, int> {
  _ControlledRestartableBloc(this._futures) : super(initialState: 0) {
    on<DelayedIncrement>(
      (event, emit) async {
        await _futures[event.value];
        emit(event.value);
      },
      transformer: restartable(),
    );
  }

  final Map<int, Future<void>> _futures;
}

class _TelemetryRecordingObserver extends BlocSignalObserver {
  final List<Object?> preemptedEvents = [];

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    if (name == BlocTelemetryKeys.taskPreempted) {
      preemptedEvents.add(event);
    }
  }
}
