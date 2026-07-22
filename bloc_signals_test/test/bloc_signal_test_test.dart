import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

// Sample Cubit for testing
class CounterCubit extends CubitSignal<int> {
  CounterCubit({int initial = 0}) : super(initialState: initial);

  void increment() => emit(stateValue + 1);
  void emitSame() => emit(stateValue);
  void incrementTwice() {
    emit(stateValue + 1);
    emit(stateValue + 1);
  }
}

// Sample Bloc for testing
abstract class CounterEvent {}

class IncrementEvent extends CounterEvent {}

class DelayedIncrementEvent extends CounterEvent {}

class ErrorEvent extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc({int initial = 0}) : super(initialState: initial) {
    on<IncrementEvent>((event, emit) {
      emit(stateValue + 1);
    });
    on<DelayedIncrementEvent>((event, emit) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      emit(stateValue + 1);
    });
    on<ErrorEvent>((event, emit) {
      throw Exception('something went wrong');
    });
  }
}

class TrackingObserver extends BlocSignalObserver {
  final created = <BlocSignalBase<dynamic>>[];
  final events = <Object?>[];
  final transitions = <Object?>[];
  final changes = <Change<dynamic>>[];
  final errors = <Object>[];
  final closed = <BlocSignalBase<dynamic>>[];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) => created.add(bloc);

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) =>
      events.add(event);

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) =>
      transitions.add(state);

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) =>
      changes.add(change);

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) =>
      errors.add(error);

  @override
  void onClose(BlocSignalBase<dynamic> bloc) => closed.add(bloc);
}

void main() {
  group('blocSignalTest', () {
    var setUpCalled = false;
    var tearDownCalled = false;
    CounterCubit? createdCubit;

    blocSignalTest<CounterCubit, int>(
      'emits [] when act is not provided',
      build: CounterCubit.new,
      expect: () => <int>[],
    );

    blocSignalTest<CounterCubit, int>(
      'emits [1] when increment is called on CounterCubit',
      build: CounterCubit.new,
      act: (cubit) => cubit.increment(),
      expect: () => [1],
    );

    blocSignalTest<CounterCubit, int>(
      'emits [1, 2] when incrementTwice is called on CounterCubit',
      build: CounterCubit.new,
      act: (cubit) => cubit.incrementTwice(),
      expect: () => [1, 2],
    );

    blocSignalTest<CounterCubit, int>(
      'de-duplicates identical state emissions (==)',
      build: CounterCubit.new,
      act: (cubit) {
        cubit
          ..emitSame()
          ..increment();
      },
      expect: () => [1],
    );

    blocSignalTest<CounterCubit, int>(
      'supports skip parameter',
      build: CounterCubit.new,
      act: (cubit) => cubit.incrementTwice(),
      skip: 1,
      expect: () => [2],
    );

    blocSignalTest<CounterBloc, int>(
      'emits [1] when IncrementEvent is added to CounterBloc',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(IncrementEvent()),
      expect: () => [1],
    );

    blocSignalTest<CounterBloc, int>(
      'supports async event handler with wait parameter',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(DelayedIncrementEvent()),
      wait: const Duration(milliseconds: 50),
      expect: () => [1],
    );

    blocSignalTest<CounterCubit, int>(
      'executes setUp, verify, and tearDown callbacks',
      setUp: () {
        setUpCalled = true;
      },
      build: CounterCubit.new,
      act: (cubit) => cubit.increment(),
      expect: () => [1],
      verify: (cubit) {
        expect(cubit.stateValue, equals(1));
        expect(setUpCalled, isTrue);
      },
      tearDown: () {
        tearDownCalled = true;
      },
    );

    test('verifies tearDown was executed after blocSignalTest', () {
      expect(tearDownCalled, isTrue);
    });

    blocSignalTest<CounterBloc, int>(
      'captures errors when an exception occurs during event handling',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(ErrorEvent()),
      expect: () => <int>[],
      errors: () => [isA<Exception>()],
    );

    blocSignalTest<CounterCubit, int>(
      'automatically closes the bloc after execution',
      build: () {
        createdCubit = CounterCubit();
        return createdCubit!;
      },
      act: (cubit) => cubit.increment(),
      expect: () => [1],
      verify: (cubit) {
        expect(cubit.isClosed, isFalse);
      },
    );

    test('verifies createdCubit is closed after blocSignalTest completion', () {
      expect(createdCubit, isNotNull);
      expect(createdCubit!.isClosed, isTrue);
    });

    group('Observer forwarding', () {
      final tracker = TrackingObserver();

      setUp(() {
        BlocSignalObserver.observer = tracker;
      });

      tearDown(() {
        BlocSignalObserver.observer = null;
      });

      blocSignalTest<CounterBloc, int>(
        'delegates all observer events to parent observer if present',
        build: CounterBloc.new,
        act: (bloc) {
          bloc
            ..add(IncrementEvent())
            ..add(ErrorEvent());
        },
        expect: () => [1],
        errors: () => [isA<Exception>()],
        verify: (bloc) {
          expect(tracker.created, hasLength(1));
          expect(tracker.events, hasLength(2));
          expect(tracker.transitions, hasLength(1));
          expect(tracker.changes, hasLength(1));
          expect(tracker.errors, hasLength(1));
        },
      );

      test('verifies parent observer received onClose', () {
        expect(tracker.closed, hasLength(1));
      });
    });
  });
}
