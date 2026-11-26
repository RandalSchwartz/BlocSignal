import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:signals_core/signals_core.dart';
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

  void failSync() {
    throw StateError('cubit sync state error');
  }

  Future<void> failAsync() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    throw StateError('cubit async state error');
  }
}

// Sample Bloc for testing
abstract class CounterEvent {}

class IncrementEvent extends CounterEvent {}

class DelayedIncrementEvent extends CounterEvent {}

class ErrorEvent extends CounterEvent {}

class StateErrorEvent extends CounterEvent {}

class AsyncErrorEvent extends CounterEvent {}

class ImmediateAsyncErrorEvent extends CounterEvent {}

class _UnregisteredEvent extends CounterEvent {}

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
    on<StateErrorEvent>((event, emit) {
      throw StateError('handler state error');
    });
    on<AsyncErrorEvent>((event, emit) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      throw ArgumentError('async handler argument error');
    });
    on<ImmediateAsyncErrorEvent>((event, emit) async {
      throw ArgumentError('immediate async handler argument error');
    });
  }
}

class TrackingObserver extends BlocSignalObserver {
  final created = <BlocSignalBase<dynamic>>[];
  final events = <Object?>[];
  final eventsCompleted = <Object?>[];
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
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) =>
      eventsCompleted.add(event);

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
          expect(tracker.eventsCompleted, hasLength(2));
          expect(tracker.transitions, hasLength(1));
          expect(tracker.changes, hasLength(1));
          expect(tracker.errors, hasLength(1));
        },
      );

      test('verifies parent observer received onClose', () {
        expect(tracker.closed, hasLength(1));
      });
    });

    group('(Issue #297: F14, F15) setUp observer scoping', () {
      final baselineObserver = TrackingObserver();
      final setupObserver = TrackingObserver();

      test('initializes baseline observer', () {
        BlocSignalObserver.observer = baselineObserver;
      });

      blocSignalTest<CounterBloc, int>(
        'installs custom observer inside setUp and forwards events to it',
        setUp: () {
          BlocSignalObserver.observer = setupObserver;
        },
        build: CounterBloc.new,
        act: (bloc) => bloc.add(IncrementEvent()),
        expect: () => [1],
        verify: (bloc) {
          expect(setupObserver.created, hasLength(1));
          expect(setupObserver.events, hasLength(1));
          expect(setupObserver.eventsCompleted, hasLength(1));
          expect(setupObserver.transitions, hasLength(1));
          expect(setupObserver.changes, hasLength(1));
        },
      );

      test('verifies observer reverted to baselineObserver after test', () {
        expect(BlocSignalObserver.observer, equals(baselineObserver));
        expect(baselineObserver.events, isEmpty);
      });

      tearDownAll(() {
        BlocSignalObserver.observer = null;
      });
    });

    group('expectTelemetry verification', () {
      blocSignalTest<_TelemetryTestCubit, int>(
        'verifies emitted telemetry matching isTelemetry',
        build: _TelemetryTestCubit.new,
        act: (cubit) => cubit.incrementWithTelemetry(),
        expect: () => [1],
        expectTelemetry: () => [
          isTelemetry(
            'counter_incremented',
            metadata: {'current': 0},
          ),
        ],
      );

      test('isTelemetry matches name, event, and metadata subset', () {
        const entry = BlocTelemetryEntry(
          name: 'event_dropped',
          event: 'query_text',
          metadata: {'reason': 'in_flight', 'extra': 123},
        );

        expect(entry.toString(), contains('name: event_dropped'));
        expect(isTelemetry('event_dropped').matches(entry, {}), isTrue);
        expect(
          isTelemetry('event_dropped', event: 'query_text').matches(entry, {}),
          isTrue,
        );
        expect(
          isTelemetry('event_dropped', metadata: {'reason': 'in_flight'})
              .matches(entry, {}),
          isTrue,
        );
        expect(
          isTelemetry('other_name').matches(entry, {}),
          isFalse,
        );
        expect(
          isTelemetry('event_dropped', event: 'other').matches(entry, {}),
          isFalse,
        );
        expect(
          isTelemetry('event_dropped', metadata: {'reason': 'other'})
              .matches(entry, {}),
          isFalse,
        );
        expect(
          isTelemetry('event_dropped', metadata: {'missing': 'val'})
              .matches(entry, {}),
          isFalse,
        );
        expect(
          isTelemetry('event_dropped').matches('not an entry', {}),
          isFalse,
        );

        const nullMetaEntry = BlocTelemetryEntry(name: 'event_dropped');
        expect(
          isTelemetry('event_dropped', metadata: {'reason': 'in_flight'})
              .matches(nullMetaEntry, {}),
          isFalse,
        );

        final description = StringDescription();
        isTelemetry(
          'event_dropped',
          event: 'query',
          metadata: {'k': 'v'},
        ).describe(description);
        expect(description.toString(), contains('event_dropped'));
      });

      test(
        '(Issue #483) isTelemetry matches Matcher predicates and collection '
        'matchers in metadata and describes mismatches clearly',
        () {
          const entry = BlocTelemetryEntry(
            name: 'batch_processed',
            event: 'sync_event',
            metadata: {
              'count': 5,
              'tags': ['alpha', 'beta'],
            },
          );

          expect(
            entry,
            isTelemetry(
              'batch_processed',
              metadata: {
                'count': greaterThanOrEqualTo(5),
                'tags': contains('beta'),
              },
            ),
          );

          String mismatchFor(Matcher matcher, Object? actual) {
            final matchState = <dynamic, dynamic>{};
            expect(matcher.matches(actual, matchState), isFalse);
            final desc = StringDescription();
            matcher.describeMismatch(actual, desc, matchState, false);
            return desc.toString();
          }

          expect(
            mismatchFor(isTelemetry('batch_processed'), 'not_an_entry'),
            contains('BlocTelemetryEntry'),
          );
          expect(
            mismatchFor(isTelemetry('other_name'), entry),
            contains('name'),
          );
          expect(
            mismatchFor(
              isTelemetry('batch_processed', event: 'other_event'),
              entry,
            ),
            contains('event'),
          );
          expect(
            mismatchFor(
              isTelemetry('batch_processed', metadata: {'missing': 1}),
              entry,
            ),
            contains('missing'),
          );
          expect(
            mismatchFor(
              isTelemetry('batch_processed', metadata: {'count': 1}),
              const BlocTelemetryEntry(name: 'batch_processed'),
            ),
            contains('metadata'),
          );
          expect(
            mismatchFor(
              isTelemetry(
                'batch_processed',
                metadata: {'count': greaterThan(10)},
              ),
              entry,
            ),
            contains('count'),
          );

          final fallbackDesc = StringDescription();
          isTelemetry('batch_processed').describeMismatch(
            'raw_item',
            fallbackDesc,
            <dynamic, dynamic>{},
            false,
          );
          expect(fallbackDesc.toString(), isEmpty);
        },
      );
      blocSignalTest<_ConstructorTelemetryCubit, int>(
        'captures telemetry emitted during build construction',
        build: _ConstructorTelemetryCubit.new,
        expectTelemetry: () => [
          isTelemetry('cubit_initialized', metadata: {'initial': 42}),
        ],
      );
      blocSignalTest<_ConstructorErrorCubit, int>(
        'captures errors emitted during build construction',
        build: _ConstructorErrorCubit.new,
        errors: () => [isA<Exception>()],
      );
    });

    group('(Issue #328: R14) Capture rethrown Error subtypes in blocSignalTest',
        () {
      blocSignalTest<CounterBloc, int>(
        'captures synchronous StateError rethrown by BlocSignal event handler '
        'without duplicating onError entry',
        build: CounterBloc.new,
        act: (bloc) => bloc.add(StateErrorEvent()),
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'handler state error',
          ),
        ],
      );

      blocSignalTest<CounterBloc, int>(
        'captures StateError rethrown on unregistered event dispatch '
        'without duplicating onError entry',
        build: CounterBloc.new,
        act: (bloc) => bloc.add(_UnregisteredEvent()),
        expect: () => <int>[],
        errors: () => [isA<StateError>()],
      );

      blocSignalTest<CounterBloc, int>(
        'captures asynchronous ArgumentError rethrown by async BlocSignal '
        'handler with wait',
        build: CounterBloc.new,
        act: (bloc) => bloc.add(AsyncErrorEvent()),
        wait: const Duration(milliseconds: 30),
        expect: () => <int>[],
        errors: () => [
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'async handler argument error',
          ),
        ],
      );

      blocSignalTest<CounterBloc, int>(
        'captures immediate asynchronous ArgumentError rethrown by async '
        'BlocSignal handler without wait',
        build: CounterBloc.new,
        act: (bloc) => bloc.add(ImmediateAsyncErrorEvent()),
        expect: () => <int>[],
        errors: () => [
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'immediate async handler argument error',
          ),
        ],
      );

      blocSignalTest<CounterCubit, int>(
        'captures synchronous StateError thrown directly by CubitSignal method',
        build: CounterCubit.new,
        act: (cubit) => cubit.failSync(),
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'cubit sync state error',
          ),
        ],
      );

      blocSignalTest<CounterCubit, int>(
        'captures asynchronous StateError thrown directly by CubitSignal '
        'method',
        build: CounterCubit.new,
        act: (cubit) => cubit.failAsync(),
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'cubit async state error',
          ),
        ],
      );

      blocSignalTest<CounterCubit, int>(
        'captures unawaited asynchronous StateError thrown inside act during '
        'wait',
        build: CounterCubit.new,
        act: (_) {
          unawaited(
            Future<void>.microtask(
              () => throw StateError('unawaited async'),
            ),
          );
        },
        wait: const Duration(milliseconds: 10),
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'unawaited async',
          ),
        ],
      );

      test(
        'rethrows synchronous StateError from BlocSignal handler when errors '
        'is omitted and cleans up container and observer',
        () async {
          final baseline = TrackingObserver();
          BlocSignalObserver.observer = baseline;
          addTearDown(() => BlocSignalObserver.observer = null);

          CounterBloc? builtBloc;
          await expectLater(
            runBlocSignalTest<CounterBloc, int>(
              build: () => builtBloc = CounterBloc(),
              act: (bloc) => bloc.add(StateErrorEvent()),
            ),
            throwsA(isA<StateError>()),
          );

          expect(builtBloc, isNotNull);
          expect(builtBloc!.isClosed, isTrue);
          expect(BlocSignalObserver.observer, same(baseline));
        },
      );

      test(
        'rethrows asynchronous ArgumentError from BlocSignal handler when '
        'errors is omitted and cleans up container and observer',
        () async {
          final baseline = TrackingObserver();
          BlocSignalObserver.observer = baseline;
          addTearDown(() => BlocSignalObserver.observer = null);

          CounterBloc? builtBloc;
          await expectLater(
            runBlocSignalTest<CounterBloc, int>(
              build: () => builtBloc = CounterBloc(),
              act: (bloc) => bloc.add(AsyncErrorEvent()),
              wait: const Duration(milliseconds: 30),
            ),
            throwsA(isA<ArgumentError>()),
          );

          expect(builtBloc, isNotNull);
          expect(builtBloc!.isClosed, isTrue);
          expect(BlocSignalObserver.observer, same(baseline));
        },
      );

      test(
        'rethrows synchronous StateError from CubitSignal method when errors '
        'is omitted and cleans up container and observer',
        () async {
          final baseline = TrackingObserver();
          BlocSignalObserver.observer = baseline;
          addTearDown(() => BlocSignalObserver.observer = null);

          CounterCubit? builtCubit;
          await expectLater(
            runBlocSignalTest<CounterCubit, int>(
              build: () => builtCubit = CounterCubit(),
              act: (cubit) => cubit.failSync(),
            ),
            throwsA(isA<StateError>()),
          );

          expect(builtCubit, isNotNull);
          expect(builtCubit!.isClosed, isTrue);
          expect(BlocSignalObserver.observer, same(baseline));
        },
      );

      test(
        '(Issue #328: R14, Blocker 1) forwards late asynchronous errors '
        'occurring after wait completion to parent zone handleUncaughtError',
        () async {
          final lateErrors = <Object>[];
          final lateCompleter = Completer<void>();

          await runZonedGuarded(
            () async {
              await runBlocSignalTest<CounterCubit, int>(
                build: CounterCubit.new,
                act: (cubit) {
                  Timer(
                    const Duration(milliseconds: 30),
                    () => throw StateError('late background crash'),
                  );
                },
                wait: const Duration(milliseconds: 5),
              );
            },
            (error, stackTrace) {
              lateErrors.add(error);
              if (!lateCompleter.isCompleted) {
                lateCompleter.complete();
              }
            },
          );

          await lateCompleter.future.timeout(const Duration(milliseconds: 200));
          expect(lateErrors, [isA<StateError>()]);
        },
      );
    });

    group('(Issue #499) FakeAsync virtual-time support', () {
      var fakeSetUpCalled = false;
      var fakeTearDownCalled = false;
      _TimerCubit? createdTimerCubit;

      blocSignalTest<_TimerCubit, int>(
        'advances virtual time with wait without wall-clock delay',
        build: _TimerCubit.new,
        act: (cubit) => cubit.incrementAfter(const Duration(seconds: 30)),
        fakeAsync: true,
        wait: const Duration(seconds: 30),
        expect: () => [1],
      );

      blocSignalTest<_DebounceCubit, int>(
        'supports multi-step elapse inside act for debounce flows',
        build: _DebounceCubit.new,
        act: (cubit) {
          cubit.scheduleIncrement(1, const Duration(seconds: 5));
          elapse(const Duration(seconds: 3));
          // Second call cancels the first timer before it fires.
          cubit.scheduleIncrement(2, const Duration(seconds: 5));
          elapse(const Duration(seconds: 4));
          // Still pending at 4s; advance past 5s.
          elapse(const Duration(seconds: 1));
        },
        fakeAsync: true,
        expect: () => [2],
      );

      blocSignalTest<_TimerCubit, int>(
        'supports flushMicrotasks inside act without advancing virtual clock',
        build: _TimerCubit.new,
        act: (cubit) {
          scheduleMicrotask(cubit.increment);
          flushMicrotasks();
          expect(cubit.stateValue, equals(1));
        },
        fakeAsync: true,
        expect: () => [1],
      );

      test(
        'fails when uncaught timer error occurs under fakeAsync and errors '
        'is omitted',
        () async {
          await expectLater(
            runBlocSignalTest<_TimerCubit, int>(
              build: _TimerCubit.new,
              act: (cubit) => cubit.throwInTimer(
                const Duration(seconds: 10),
                StateError('timer crash'),
              ),
              fakeAsync: true,
              wait: const Duration(seconds: 10),
            ),
            throwsA(isA<StateError>()),
          );
        },
      );

      blocSignalTest<_TimerCubit, int>(
        'captures expected timer error when errors matcher is provided',
        build: _TimerCubit.new,
        act: (cubit) => cubit.throwInTimer(
          const Duration(seconds: 10),
          StateError('expected timer crash'),
        ),
        fakeAsync: true,
        wait: const Duration(seconds: 10),
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'expected timer crash',
          ),
        ],
      );

      blocSignalTest<CounterCubit, int>(
        'captures synchronous throw in act under fakeAsync',
        build: CounterCubit.new,
        act: (cubit) => cubit.failSync(),
        fakeAsync: true,
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'cubit sync state error',
          ),
        ],
      );

      test(
        'elapse throws StateError when called outside fakeAsync',
        () {
          expect(
            () => elapse(const Duration(seconds: 1)),
            throwsA(isA<StateError>()),
          );
        },
      );

      test(
        'flushMicrotasks throws StateError when called outside fakeAsync',
        () {
          expect(
            flushMicrotasks,
            throwsA(isA<StateError>()),
          );
        },
      );

      blocSignalTest<_TimerCubit, int>(
        'preserves setUp, tearDown, skip, verify, expectTelemetry, and close '
        'parity under fakeAsync',
        setUp: () {
          fakeSetUpCalled = true;
        },
        build: () {
          createdTimerCubit = _TimerCubit();
          return createdTimerCubit!;
        },
        act: (cubit) {
          cubit
            ..incrementWithTelemetry()
            ..incrementAfter(const Duration(seconds: 5));
        },
        fakeAsync: true,
        wait: const Duration(seconds: 5),
        skip: 1,
        expect: () => [2],
        expectTelemetry: () => [
          isTelemetry('timer_incremented', metadata: {'current': 0}),
        ],
        verify: (cubit) {
          expect(fakeSetUpCalled, isTrue);
          expect(cubit.isClosed, isFalse);
          expect(cubit.stateValue, equals(2));
        },
        tearDown: () {
          fakeTearDownCalled = true;
        },
      );

      test(
        'verifies tearDown and bloc.close() ran after fakeAsync test',
        () {
          expect(fakeTearDownCalled, isTrue);
          expect(createdTimerCubit, isNotNull);
          expect(createdTimerCubit!.isClosed, isTrue);
        },
      );

      blocSignalTest<_TimerCubit, int>(
        'supports act returning a Future that succeeds under fakeAsync',
        build: _TimerCubit.new,
        act: (cubit) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          cubit.increment();
        },
        fakeAsync: true,
        wait: const Duration(seconds: 5),
        expect: () => [1],
      );

      blocSignalTest<_TimerCubit, int>(
        'captures async error from Future returned by act under fakeAsync',
        build: _TimerCubit.new,
        act: (cubit) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          throw ArgumentError('async act failure');
        },
        fakeAsync: true,
        wait: const Duration(seconds: 5),
        expect: () => <int>[],
        errors: () => [
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'async act failure',
          ),
        ],
      );

      blocSignalTest<_ConstructorTimerCubit, int>(
        'captures constructor-scheduled Timer inside build with act null and '
        'wait under fakeAsync',
        build: _ConstructorTimerCubit.new,
        fakeAsync: true,
        wait: const Duration(seconds: 15),
        expect: () => [1],
      );

      test(
        'propagates synchronous build() throw under fakeAsync and restores '
        'baseline observer',
        () async {
          final baseline = TrackingObserver();
          BlocSignalObserver.observer = baseline;
          addTearDown(() => BlocSignalObserver.observer = null);

          var tearDownCalled = false;
          await expectLater(
            runBlocSignalTest<CounterCubit, int>(
              build: () => throw StateError('build boom'),
              fakeAsync: true,
              tearDown: () {
                tearDownCalled = true;
              },
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                'build boom',
              ),
            ),
          );

          expect(BlocSignalObserver.observer, same(baseline));
          expect(tearDownCalled, isTrue);
        },
      );

      blocSignalTest<CounterCubit, int>(
        'captures failing non-void Future<int> returned by act under fakeAsync',
        build: CounterCubit.new,
        act: (cubit) => Future<int>.delayed(
          const Duration(seconds: 2),
          () => throw StateError('typed future error'),
        ),
        fakeAsync: true,
        wait: const Duration(seconds: 2),
        expect: () => <int>[],
        errors: () => [
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'typed future error',
          ),
        ],
      );

      test(
        'rethrows synchronous and asynchronous act errors (including '
        'Future<int>) when errors is omitted under fakeAsync and cleans up',
        () async {
          final baseline = TrackingObserver();
          BlocSignalObserver.observer = baseline;
          addTearDown(() => BlocSignalObserver.observer = null);

          CounterCubit? syncCubit;
          await expectLater(
            runBlocSignalTest<CounterCubit, int>(
              build: () => syncCubit = CounterCubit(),
              act: (cubit) => cubit.failSync(),
              fakeAsync: true,
            ),
            throwsA(isA<StateError>()),
          );
          expect(syncCubit!.isClosed, isTrue);
          expect(BlocSignalObserver.observer, same(baseline));

          CounterCubit? asyncCubit;
          await expectLater(
            runBlocSignalTest<CounterCubit, int>(
              build: () => asyncCubit = CounterCubit(),
              act: (_) => Future<int>.delayed(
                const Duration(seconds: 2),
                () => throw ArgumentError('omitted typed future error'),
              ),
              fakeAsync: true,
              wait: const Duration(seconds: 2),
            ),
            throwsA(isA<ArgumentError>()),
          );
          expect(asyncCubit!.isClosed, isTrue);
          expect(BlocSignalObserver.observer, same(baseline));
        },
      );

      blocSignalTest<_TransformedBloc, int>(
        'supports BlocSignal debounce() transformer under fakeAsync',
        build: _TransformedBloc.new,
        act: (bloc) {
          bloc.add(const _DebouncedEvent(1));
          elapse(const Duration(milliseconds: 200));
          bloc.add(const _DebouncedEvent(2));
          elapse(const Duration(milliseconds: 300));
        },
        fakeAsync: true,
        expect: () => [2],
      );

      blocSignalTest<_TransformedBloc, int>(
        'supports BlocSignal throttle() transformer under fakeAsync',
        build: _TransformedBloc.new,
        act: (bloc) {
          bloc
            ..add(const _ThrottledEvent(1))
            ..add(const _ThrottledEvent(2));
          elapse(const Duration(milliseconds: 500));
          bloc.add(const _ThrottledEvent(3));
        },
        fakeAsync: true,
        expect: () => [1, 3],
      );

      blocSignalTest<CounterBloc, int>(
        'deduplicates async BlocSignal handler onError and rethrow under '
        'fakeAsync',
        build: CounterBloc.new,
        act: (bloc) => bloc.add(AsyncErrorEvent()),
        fakeAsync: true,
        wait: const Duration(milliseconds: 20),
        expect: () => <int>[],
        errors: () => [
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'async handler argument error',
          ),
        ],
      );
    });
    group('(Issue #483) lifecycle, seed, expectComputed, and sync fast-path',
        () {
      test(
        'restores baselineObserver and runs tearDown when setUp throws',
        () async {
          final baselineObserver = TrackingObserver();
          final setupObserver = TrackingObserver();
          BlocSignalObserver.observer = baselineObserver;
          addTearDown(() => BlocSignalObserver.observer = null);

          var tearDownCalled = false;

          await expectLater(
            runBlocSignalTest<CounterCubit, int>(
              setUp: () {
                BlocSignalObserver.observer = setupObserver;
                throw StateError('setUp failed');
              },
              build: CounterCubit.new,
              tearDown: () {
                tearDownCalled = true;
              },
            ),
            throwsA(isA<StateError>()),
          );

          expect(tearDownCalled, isTrue);
          expect(BlocSignalObserver.observer, same(baselineObserver));
        },
      );

      blocSignalTest<CounterCubit, int>(
        'seed injects initial state before subscription without recording it',
        build: CounterCubit.new,
        seed: () => 10,
        act: (cubit) => cubit.increment(),
        expect: () => [11],
      );

      blocSignalTest<CounterCubit, int>(
        'seed does not record an emission when act is omitted',
        build: CounterCubit.new,
        seed: () => 42,
        expect: () => <int>[],
        verify: (cubit) {
          expect(cubit.stateValue, equals(42));
        },
      );

      blocSignalTest<_ComputedCounterCubit, int>(
        'expectComputed asserts computed signals with literal values and '
        'Matchers',
        build: _ComputedCounterCubit.new,
        act: (cubit) => cubit.increment(),
        expect: () => [1],
        expectComputed: (cubit) => <ReadonlySignal<Object?>, Object?>{
          cubit.doubled: 2,
          cubit.label: contains('1'),
        },
      );

      test(
        'synchronous blocSignalTest without wait drains microtasks without '
        'allocating a Timer',
        () async {
          var timerAllocated = false;
          await runZoned(
            () => runBlocSignalTest<CounterCubit, int>(
              build: CounterCubit.new,
              act: (cubit) {
                unawaited(Future<void>.microtask(cubit.increment));
              },
              expect: () => [1],
            ),
            zoneSpecification: ZoneSpecification(
              createTimer: (self, parent, zone, duration, f) {
                timerAllocated = true;
                return parent.createTimer(zone, duration, f);
              },
              createPeriodicTimer: (self, parent, zone, period, f) {
                timerAllocated = true;
                return parent.createPeriodicTimer(zone, period, f);
              },
            ),
          );

          expect(timerAllocated, isFalse);
        },
      );

      blocSignalTest<_SequentialAsyncBloc, int>(
        'drains sequential() back-to-back async events without wait',
        build: _SequentialAsyncBloc.new,
        act: (bloc) {
          bloc
            ..add(const _SeqAddEvent(1))
            ..add(const _SeqAddEvent(1));
        },
        expect: () => [1, 2],
      );

      blocSignalTest<_MultiHopErrorBloc, int>(
        'captures multi-hop async BlocSignal handler throw without wait '
        'or parentZone leak',
        build: _MultiHopErrorBloc.new,
        act: (bloc) => bloc.add(const _BoomEvent()),
        expect: () => <int>[],
        errors: () => [
          isA<Exception>().having(
            (e) => e.toString(),
            'toString()',
            contains('boom'),
          ),
        ],
      );

      blocSignalTest<BlocSignalBase<AsyncState<String>>, AsyncState<String>>(
        'drains Future.value().toAsyncBlocSignal() microtasks initiated in '
        'build without wait',
        build: () => Future<String>.value('Alice').toAsyncBlocSignal(),
        expect: () => <Object>[const AsyncData<String>('Alice')],
      );

      blocSignalTest<_ConstructorSequentialBloc, int>(
        'drains constructor-dispatched sequential() events without wait',
        build: _ConstructorSequentialBloc.new,
        expect: () => [1, 2],
      );
    });
  });
}

class _ConstructorSequentialBloc extends BlocSignal<_SeqAddEvent, int> {
  _ConstructorSequentialBloc() : super(initialState: 0) {
    on<_SeqAddEvent>(
      (event, emit) async {
        await Future<void>.value();
        emit(stateValue + event.delta);
      },
      transformer: sequential(),
    );
    add(const _SeqAddEvent(1));
    add(const _SeqAddEvent(1));
  }
}

class _SeqAddEvent {
  const _SeqAddEvent(this.delta);
  final int delta;
}

class _SequentialAsyncBloc extends BlocSignal<_SeqAddEvent, int> {
  _SequentialAsyncBloc() : super(initialState: 0) {
    on<_SeqAddEvent>(
      (event, emit) async {
        await Future<void>.value();
        emit(stateValue + event.delta);
      },
      transformer: sequential(),
    );
  }
}

class _BoomEvent {
  const _BoomEvent();
}

class _MultiHopErrorBloc extends BlocSignal<_BoomEvent, int> {
  _MultiHopErrorBloc() : super(initialState: 0) {
    on<_BoomEvent>((event, emit) async {
      await Future<void>.value();
      await Future<void>.value();
      throw Exception('boom');
    });
  }
}

class _ComputedCounterCubit extends CubitSignal<int> {
  _ComputedCounterCubit() : super(initialState: 0);

  late final Computed<int> doubled = computed(() => stateValue * 2);
  late final Computed<String> label = computed(() => 'count:$stateValue');

  void increment() => emit(stateValue + 1);
}

class _TelemetryTestCubit extends CubitSignal<int> {
  _TelemetryTestCubit() : super(initialState: 0);

  void incrementWithTelemetry() {
    emitTelemetry('counter_incremented', metadata: {'current': stateValue});
    emit(stateValue + 1);
  }
}

class _ConstructorTelemetryCubit extends CubitSignal<int> {
  _ConstructorTelemetryCubit() : super(initialState: 42) {
    emitTelemetry('cubit_initialized', metadata: {'initial': 42});
  }
}

class _ConstructorErrorCubit extends CubitSignal<int> {
  _ConstructorErrorCubit() : super(initialState: 0) {
    emitError(Exception('error during construction'));
  }
}

class _TimerCubit extends CubitSignal<int> {
  _TimerCubit() : super(initialState: 0);

  Timer? _timer;

  void increment() => emit(stateValue + 1);

  void incrementWithTelemetry() {
    emitTelemetry('timer_incremented', metadata: {'current': stateValue});
    emit(stateValue + 1);
  }

  void incrementAfter(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => emit(stateValue + 1));
  }

  void throwInTimer(Duration delay, Object error) {
    _timer?.cancel();
    _timer = Timer(
      delay,
      () => Error.throwWithStackTrace(error, StackTrace.current),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

class _DebounceCubit extends CubitSignal<int> {
  _DebounceCubit() : super(initialState: 0);

  Timer? _debounceTimer;

  void scheduleIncrement(int target, Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () => emit(target));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}

class _ConstructorTimerCubit extends CubitSignal<int> {
  _ConstructorTimerCubit() : super(initialState: 0) {
    _timer = Timer(const Duration(seconds: 15), () => emit(1));
  }

  Timer? _timer;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

abstract class _TransformedEvent {
  const _TransformedEvent();
}

class _DebouncedEvent extends _TransformedEvent {
  const _DebouncedEvent(this.value);
  final int value;
}

class _ThrottledEvent extends _TransformedEvent {
  const _ThrottledEvent(this.value);
  final int value;
}

class _TransformedBloc extends BlocSignal<_TransformedEvent, int> {
  _TransformedBloc() : super(initialState: 0) {
    on<_DebouncedEvent>(
      (event, emit) => emit(event.value),
      transformer: debounce(const Duration(milliseconds: 300)),
    );
    on<_ThrottledEvent>(
      (event, emit) => emit(event.value),
      transformer: throttle(const Duration(milliseconds: 500)),
    );
  }
}
