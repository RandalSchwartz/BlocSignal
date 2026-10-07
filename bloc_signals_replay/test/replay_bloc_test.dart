import 'dart:async';

import 'package:bloc_signals_replay/bloc_signals_replay.dart';
import 'package:test/test.dart';

import 'blocs/counter_bloc.dart';

class TestBlocObserver extends BlocSignalObserver {
  final events = <Object?>[];
  final transitions = <Transition<dynamic, dynamic>>[];

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    events.add(event);
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    transitions.add(
      Transition<dynamic, dynamic>(
        currentState: bloc.stateValue,
        event: event,
        nextState: state,
      ),
    );
  }
}

void main() {
  group('ReplayBloc', () {
    group('initial state', () {
      test('is correct', () {
        expect(CounterBloc().stateValue, 0);
      });
    });

    group('canUndo', () {
      test('is false when no state changes have occurred', () async {
        final bloc = CounterBloc();
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });

      test('is true when a single state change has occurred', () async {
        final bloc = CounterBloc()..add(const CounterIncrementPressed());
        expect(bloc.canUndo, isTrue);
        await bloc.close();
      });

      test('is false when undos have been exhausted', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo();
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });
    });

    group('canRedo', () {
      test('is false when no state changes have occurred', () async {
        final bloc = CounterBloc();
        expect(bloc.canRedo, isFalse);
        await bloc.close();
      });

      test('is true when a single undo has occurred', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo();
        expect(bloc.canRedo, isTrue);
        await bloc.close();
      });

      test('is false when redos have been exhausted', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo()
          ..redo();
        expect(bloc.canRedo, isFalse);
        await bloc.close();
      });

      test('does not clear redos when equal state is emitted', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo();
        expect(bloc.canRedo, isTrue);
        bloc.add(const CounterNoOpPressed());
        expect(bloc.canRedo, isTrue);
        await bloc.close();
      });

      test('does not add undo entry when equal state is emitted', () async {
        final bloc = CounterBloc()..add(const CounterNoOpPressed());
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });

      test('does not record history after close', () async {
        final bloc = CounterBloc();
        await bloc.close();
        bloc.add(const CounterIncrementPressed());
        expect(bloc.canUndo, isFalse);
      });

      test(
        '(Issue #297: F6) does not mutate history or throw when undo or redo '
        'is called after close',
        () async {
          final bloc = CounterBloc()..add(const CounterIncrementPressed());
          expect(bloc.canUndo, isTrue);
          expect(bloc.canRedo, isFalse);
          await bloc.close();

          expect(bloc.undo, returnsNormally);
          expect(bloc.stateValue, equals(1));
          expect(bloc.canUndo, isTrue);
          expect(bloc.canRedo, isFalse);

          expect(bloc.redo, returnsNormally);
          expect(bloc.stateValue, equals(1));
          expect(bloc.canUndo, isTrue);
          expect(bloc.canRedo, isFalse);
        },
      );
    });

    group('clearHistory', () {
      test('clears history and redos on new bloc', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..clearHistory();
        expect(bloc.canRedo, isFalse);
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });
    });

    group('undo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc.undo();
        await bloc.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when limit is 0', () async {
        final states = <int>[];
        final bloc = CounterBloc(limit: 0);
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1]);
      });

      test('skips states filtered out by shouldReplay at undo time', () async {
        final states = <int>[];
        final bloc = CounterBloc(shouldReplayCallback: (i) => !i.isEven);
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo()
          ..undo()
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 3, 1]);
      });

      test('reverts to initial state', () async {
        final states = <int>[];
        final observer = TestBlocObserver();
        BlocSignalObserver.observer = observer;
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 0]);
        expect(
          observer.events.map((e) => e.toString()),
          ['CounterIncrementPressed', 'Undo'],
        );
      });

      test('reverts to previous state with multiple state changes', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 1]);
      });
    });

    group('redo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc.redo();
        await bloc.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when no undos have occurred', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..redo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2]);
      });

      test('works when one undo has occurred', () async {
        final states = <int>[];
        final observer = TestBlocObserver();
        BlocSignalObserver.observer = observer;
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo()
          ..redo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
        expect(observer.events.map((e) => e.toString()), [
          'CounterIncrementPressed',
          'CounterIncrementPressed',
          'Undo',
          'Redo',
        ]);
        expect(observer.transitions.length, 4);
      });

      test('does nothing when undos have been exhausted', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo()
          ..redo()
          ..redo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
      });
    });
  });

  group('CounterBlocMixin', () {
    test('works as expected', () async {
      final states = <int>[];
      final bloc = CounterBlocMixin();
      final dispose = bloc.state.subscribe(states.add);
      bloc
        ..add(const CounterIncrementPressed())
        ..add(const CounterIncrementPressed())
        ..undo()
        ..redo();
      await bloc.close();
      dispose();
      expect(states, [0, 1, 2, 1, 2]);
    });

    group('named constructor & history limits ergonomics', () {
      test(
        'supports named initialState and maxHistoryLength parameter',
        () async {
          final bloc = _NamedCounterBloc(
            initialState: 10,
            maxHistoryLength: 2,
          );
          expect(bloc.stateValue, 10);
          bloc
            ..add(const CounterIncrementPressed())
            ..add(const CounterIncrementPressed())
            ..add(const CounterIncrementPressed());
          expect(bloc.stateValue, 13);
          bloc.undo();
          expect(bloc.stateValue, 12);
          bloc.undo();
          expect(bloc.stateValue, 11);
          expect(bloc.canUndo, isFalse);
          await bloc.close();
        },
      );

      test(
        'supports deprecated positional constructor for backward compatibility',
        () async {
          final bloc = _PositionalCounterBloc(10, limit: 2);
          expect(bloc.stateValue, 10);
          bloc
            ..add(const CounterIncrementPressed())
            ..add(const CounterIncrementPressed())
            ..add(const CounterIncrementPressed());
          expect(bloc.stateValue, 13);
          bloc.undo();
          expect(bloc.stateValue, 12);
          bloc.undo();
          expect(bloc.stateValue, 11);
          expect(bloc.canUndo, isFalse);
          await bloc.close();
        },
      );
    });
  });

  group('(Issue #317: R3) observer and onEvent exception isolation', () {
    test(
      'isolates BlocSignalObserver exceptions in onEvent, onTransition, and '
      'onChange during undo and redo without aborting state restoration',
      () async {
        addTearDown(() => BlocSignalObserver.observer = null);
        BlocSignalObserver.observer = _ThrowingReplayObserver();

        final errors = <Object>[];
        final bloc = _ErrorRecordingCounterBloc(onErrorCallback: errors.add);
        addTearDown(bloc.close);

        bloc.add(const CounterIncrementPressed());
        expect(bloc.stateValue, equals(1));
        expect(bloc.canUndo, isTrue);
        expect(bloc.canRedo, isFalse);
        errors.clear();

        expect(bloc.undo, returnsNormally);
        expect(bloc.stateValue, equals(0));
        expect(bloc.canUndo, isFalse);
        expect(bloc.canRedo, isTrue);
        expect(
          errors.map((e) => e.toString()),
          containsAll([
            'Exception: observer onEvent failure',
            'Exception: observer onTransition failure',
            'Exception: observer onChange failure',
          ]),
        );

        errors.clear();
        expect(bloc.redo, returnsNormally);
        expect(bloc.stateValue, equals(1));
        expect(bloc.canUndo, isTrue);
        expect(bloc.canRedo, isFalse);
        expect(
          errors.map((e) => e.toString()),
          containsAll([
            'Exception: observer onEvent failure',
            'Exception: observer onTransition failure',
            'Exception: observer onChange failure',
          ]),
        );
      },
    );

    test(
      'isolates BlocSignalObserver.onTransition exception when onTransition is '
      'invoked directly with a ReplayEvent',
      () async {
        addTearDown(() => BlocSignalObserver.observer = null);
        BlocSignalObserver.observer = _ThrowingReplayObserver();

        final errors = <Object>[];
        final bloc = _ErrorRecordingCounterBloc(onErrorCallback: errors.add);
        addTearDown(bloc.close);

        expect(
          () => bloc.onTransition(
            const Transition<ReplayEvent, int>(
              currentState: 0,
              event: _CustomReplayEvent(),
              nextState: 1,
            ),
          ),
          returnsNormally,
        );
        expect(
          errors.map((e) => e.toString()),
          equals(['Exception: observer onTransition failure']),
        );
      },
    );

    test(
      'isolates synchronous Exception in subclass onEvent override during undo '
      'and redo',
      () async {
        final errors = <Object>[];
        final bloc = _SyncThrowingOnEventBloc(onErrorCallback: errors.add);
        addTearDown(bloc.close);

        bloc.add(const CounterIncrementPressed());
        expect(bloc.stateValue, equals(1));
        errors.clear();

        expect(bloc.undo, returnsNormally);
        expect(bloc.stateValue, equals(0));
        expect(bloc.canUndo, isFalse);
        expect(bloc.canRedo, isTrue);
        expect(
          errors.map((e) => e.toString()),
          equals(['Exception: sync onEvent failure on Undo']),
        );

        errors.clear();
        expect(bloc.redo, returnsNormally);
        expect(bloc.stateValue, equals(1));
        expect(bloc.canUndo, isTrue);
        expect(bloc.canRedo, isFalse);
        expect(
          errors.map((e) => e.toString()),
          equals(['Exception: sync onEvent failure on Redo']),
        );
      },
    );

    test(
      'isolates asynchronous Exception rejection in subclass onEvent override '
      'during undo and redo',
      () async {
        final errors = <Object>[];
        final bloc = _AsyncThrowingOnEventBloc(onErrorCallback: errors.add);
        addTearDown(bloc.close);

        bloc.add(const CounterIncrementPressed());
        expect(bloc.stateValue, equals(1));
        errors.clear();

        expect(bloc.undo, returnsNormally);
        expect(bloc.stateValue, equals(0));
        expect(bloc.canUndo, isFalse);
        expect(bloc.canRedo, isTrue);
        await Future<void>.microtask(() {});
        expect(
          errors.map((e) => e.toString()),
          equals(['Exception: async onEvent failure on Undo']),
        );

        errors.clear();
        expect(bloc.redo, returnsNormally);
        expect(bloc.stateValue, equals(1));
        expect(bloc.canUndo, isTrue);
        expect(bloc.canRedo, isFalse);
        await Future<void>.microtask(() {});
        expect(
          errors.map((e) => e.toString()),
          equals(['Exception: async onEvent failure on Redo']),
        );
      },
    );

    test(
      'delegates non-ReplayEvent handleTransition calls to super',
      () async {
        final bloc = CounterBloc();
        addTearDown(bloc.close);

        expect(
          // Exercising protected handleTransition fallback for non-ReplayEvent.
          // ignore: invalid_use_of_protected_member
          () => bloc.handleTransition(Object(), 0, 1),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });
}

class _CustomReplayEvent extends ReplayEvent {
  const _CustomReplayEvent();
}

class _ThrowingReplayObserver extends BlocSignalObserver {
  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    throw Exception('observer onEvent failure');
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    throw Exception('observer onTransition failure');
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    throw Exception('observer onChange failure');
  }
}

class _ErrorRecordingCounterBloc extends ReplayBloc<CounterEvent, int> {
  _ErrorRecordingCounterBloc({required this.onErrorCallback})
      : super(initialState: 0) {
    on<CounterIncrementPressed>((event, emit) => emit(stateValue + 1));
  }

  final void Function(Object error) onErrorCallback;

  @override
  void onError(Object error, StackTrace stackTrace) {
    onErrorCallback(error);
    super.onError(error, stackTrace);
  }
}

class _SyncThrowingOnEventBloc extends _ErrorRecordingCounterBloc {
  _SyncThrowingOnEventBloc({required super.onErrorCallback});

  @override
  void onEvent(ReplayEvent event) {
    unawaited(Future.value(super.onEvent(event)));
    if (event is! CounterEvent) {
      throw Exception('sync onEvent failure on $event');
    }
  }
}

class _AsyncThrowingOnEventBloc extends _ErrorRecordingCounterBloc {
  _AsyncThrowingOnEventBloc({required super.onErrorCallback});

  @override
  Future<void> onEvent(ReplayEvent event) async {
    await super.onEvent(event);
    if (event is! CounterEvent) {
      throw Exception('async onEvent failure on $event');
    }
  }
}

class _NamedCounterBloc extends ReplayBloc<CounterEvent, int> {
  _NamedCounterBloc({required super.initialState, super.maxHistoryLength}) {
    on<CounterIncrementPressed>((event, emit) => emit(stateValue + 1));
  }
}

class _PositionalCounterBloc extends ReplayBloc<CounterEvent, int> {
  _PositionalCounterBloc(super.initialState, {super.limit})
      // Testing backward-compatible positional constructor.
      // ignore: deprecated_member_use_from_same_package
      : super.positional() {
    on<CounterIncrementPressed>((event, emit) => emit(stateValue + 1));
  }
}
