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
