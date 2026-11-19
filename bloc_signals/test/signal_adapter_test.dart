import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class _TestObserver extends BlocSignalObserver {
  Object? lastCreated;
  Object? lastClosed;
  Change<dynamic>? lastChange;

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    lastCreated = bloc;
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    lastClosed = bloc;
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    lastChange = change;
  }
}

void main() {
  group(
    'SignalBlocSignal & ReadonlySignalBlocSignalExtension (.toBlocSignal())',
    () {
      test('adapts Signal<T> and reflects initial value synchronously', () {
        final countSignal = signal<int>(42);
        final bloc = countSignal.toBlocSignal();

        expect(bloc.stateValue, equals(42));
        expect(bloc.state.value, equals(42));
        expect(bloc.signal, equals(countSignal));
        expect(bloc.isClosed, isFalse);
      });

      test('synchronously updates stateValue when underlying signal changes',
          () {
        final countSignal = signal<int>(0);
        final bloc = countSignal.toBlocSignal();

        expect(bloc.stateValue, equals(0));

        countSignal.value = 1;
        expect(bloc.stateValue, equals(1));
        expect(bloc.state.value, equals(1));

        countSignal.value = 2;
        expect(bloc.stateValue, equals(2));
      });

      test('adapts Computed<T> signal dynamically', () {
        final firstName = signal('Grace');
        final lastName = signal('Hopper');
        final fullName = computed(() => '${firstName.value} ${lastName.value}');

        final bloc = fullName.toBlocSignal();
        expect(bloc.stateValue, equals('Grace Hopper'));

        lastName.value = 'Brewster Murray';
        expect(bloc.stateValue, equals('Grace Brewster Murray'));
      });

      test(r'adapts lifted signal primitive (value.$)', () {
        final value = 100.$;
        final bloc = value.toBlocSignal();

        expect(bloc.stateValue, equals(100));

        value.value = 200;
        expect(bloc.stateValue, equals(200));
      });

      test('adapts StreamSignal to BlocSignalBase<AsyncState<T>>', () async {
        final controller = StreamController<String>();
        final streamSig = controller.stream.toStreamSignal();
        final bloc = streamSig.toBlocSignal();

        expect(bloc.stateValue, isA<AsyncLoading<String>>());

        controller.add('event-1');
        await Future<void>.delayed(Duration.zero);
        expect(bloc.stateValue, isA<AsyncData<String>>());
        expect((bloc.stateValue as AsyncData<String>).value, equals('event-1'));

        await controller.close();
        await bloc.close();
      });

      test('respects custom equals comparator (for example identical)', () {
        var customEqualsCalled = false;
        final sig = signal<List<int>>([1, 2]);

        final bloc = sig.toBlocSignal(
          equals: (prev, curr) {
            customEqualsCalled = true;
            return identical(prev, curr);
          },
        );

        final nextList = [1, 2];
        sig.value = nextList;

        expect(customEqualsCalled, isTrue);
        expect(bloc.stateValue, equals(nextList));
      });

      test('respects custom SignalOptions (name and equalityCheck)', () {
        final sig = signal<int>(10);
        final bloc = sig.toBlocSignal(
          options: const SignalOptions<int>(
            name: 'custom_signal_bloc',
          ),
        );

        expect(bloc.state.name, equals('custom_signal_bloc'));
        expect(bloc.stateValue, equals(10));
      });

      test('close() unsubscribes from signal mutations and updates lifecycle',
          () async {
        final previousObserver = BlocSignalObserver.observer;
        final observer = _TestObserver();
        BlocSignalObserver.observer = observer;

        try {
          final sig = signal<int>(1);
          final bloc = sig.toBlocSignal();

          expect(observer.lastCreated, equals(bloc));

          sig.value = 2;
          expect(bloc.stateValue, equals(2));

          await bloc.close();
          expect(bloc.isClosed, isTrue);
          expect(observer.lastClosed, equals(bloc));

          // Subsequent mutations on the underlying signal should be ignored
          sig.value = 3;
          expect(bloc.stateValue, equals(2));
        } finally {
          BlocSignalObserver.observer = previousObserver;
        }
      });

      test('SignalBlocSignal constructor direct instantiation', () async {
        final sig = signal('direct');
        final bloc = SignalBlocSignal<String>(sig);

        expect(bloc.stateValue, equals('direct'));
        sig.value = 'updated';
        expect(bloc.stateValue, equals('updated'));

        await bloc.close();
      });

      test(
        '(Issue #470) close() does NOT dispose caller-owned signal',
        () async {
          final sig = signal<int>(1);
          final bloc = sig.toBlocSignal();

          await bloc.close();

          expect(sig.disposed, isFalse);
          sig.value = 99;
          expect(sig.value, equals(99));
        },
      );
    },
  );

  group('FutureBlocSignal & Future.toBlocSignal(required initialState)', () {
    test(
      'initializes with initialState and emits resolved value on completion',
      () async {
        final completer = Completer<String>();
        final bloc = completer.future.toBlocSignal(initialState: 'initial');

        expect(bloc.stateValue, equals('initial'));

        completer.complete('resolved');
        await Future<void>.delayed(Duration.zero);

        expect(bloc.stateValue, equals('resolved'));
        await bloc.close();
      },
    );

    test('routes future error rejection to onError observer callback',
        () async {
      final completer = Completer<int>();
      final bloc = completer.future.toBlocSignal(initialState: 0);

      final exception = Exception('Async failure');
      completer.completeError(exception);
      await Future<void>.delayed(Duration.zero);

      // State value remains initial
      expect(bloc.stateValue, equals(0));

      await bloc.close();
    });

    test('close() before future completes prevents emissions or errors',
        () async {
      final completer = Completer<int>();
      final bloc = completer.future.toBlocSignal(initialState: 10);

      expect(bloc.stateValue, equals(10));
      await bloc.close();
      expect(bloc.isClosed, isTrue);

      completer.complete(99);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.stateValue, equals(10));
    });

    test('close() before future errors prevents onError dispatch', () async {
      final completer = Completer<int>();
      final bloc = completer.future.toBlocSignal(initialState: 10);

      await bloc.close();
      completer.completeError(Exception('Late error'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.stateValue, equals(10));
    });
  });

  group('FutureBlocSignalExtension (Future.toAsyncBlocSignal())', () {
    test(
      'transitions through AsyncLoading -> AsyncData on successful '
      'resolution',
      () async {
        final completer = Completer<String>();
        final bloc = completer.future.toAsyncBlocSignal();

        // Synchronous initial frame
        expect(bloc.stateValue, isA<AsyncLoading<String>>());
        expect(bloc.state.value.isLoading, isTrue);

        completer.complete('user_data');
        await Future<void>.delayed(Duration.zero);

        expect(bloc.stateValue, isA<AsyncData<String>>());
        expect(
          (bloc.stateValue as AsyncData<String>).value,
          equals('user_data'),
        );
        expect(bloc.state.value.requireValue, equals('user_data'));

        await bloc.close();
      },
    );

    test('transitions to AsyncError on future error rejection', () async {
      final completer = Completer<int>();
      final bloc = completer.future.toAsyncBlocSignal();

      expect(bloc.stateValue, isA<AsyncLoading<int>>());

      final exception = Exception('Network error');
      completer.completeError(exception);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.stateValue, isA<AsyncError<int>>());
      final errorState = bloc.stateValue as AsyncError<int>;
      expect(errorState.error, equals(exception));
      expect(bloc.state.value.hasError, isTrue);

      await bloc.close();
    });

    test('supports initialValue parameter', () async {
      final completer = Completer<int>();
      final bloc = completer.future.toAsyncBlocSignal(initialValue: 99);

      // Initially has the initial value as AsyncData
      expect(bloc.stateValue, isA<AsyncData<int>>());
      expect((bloc.stateValue as AsyncData<int>).value, equals(99));

      completer.complete(100);
      await Future<void>.delayed(Duration.zero);

      expect((bloc.stateValue as AsyncData<int>).value, equals(100));

      await bloc.close();
    });

    test('supports timeout and custom options', () async {
      final completer = Completer<String>();
      final bloc = completer.future.toAsyncBlocSignal(
        timeout: const Duration(milliseconds: 20),
      );

      expect(bloc.stateValue, isA<AsyncLoading<String>>());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.stateValue, isA<AsyncError<String>>());
      expect(
        (bloc.stateValue as AsyncError<String>).error,
        isA<TimeoutException>(),
      );

      await bloc.close();
    });

    test('close() before future completes prevents further emissions',
        () async {
      final completer = Completer<int>();
      final bloc = completer.future.toAsyncBlocSignal();

      expect(bloc.stateValue, isA<AsyncLoading<int>>());

      await bloc.close();
      expect(bloc.isClosed, isTrue);

      completer.complete(42);
      await Future<void>.delayed(Duration.zero);

      // State remains AsyncLoading because bloc was closed before resolution
      expect(bloc.stateValue, isA<AsyncLoading<int>>());
    });

    test(
      '(Issue #470) close() disposes owned FutureSignal and unsubscribes '
      'dependencies',
      () async {
        var depWatchedCount = 0;
        final base = signal<int>(1);
        final dep = computed<int>(
          () => base.value * 2,
          options: ComputedOptions<int>(
            watched: () => depWatchedCount++,
            unwatched: () => depWatchedCount--,
          ),
        );
        final completer = Completer<int>();
        final bloc = completer.future.toAsyncBlocSignal(
          lazy: false,
          dependencies: [dep],
        );

        expect(bloc.signal.disposed, isFalse);
        expect(depWatchedCount, equals(1));

        await bloc.close();

        expect(bloc.signal.disposed, isTrue);
        expect(depWatchedCount, equals(0));
      },
    );

    test(
      '(Issue #470) pending Future settling with value after close() does not '
      'throw SignalsWriteAfterDisposeError or unhandled async error',
      () async {
        final uncaughtErrors = <Object>[];
        await runZonedGuarded(
          () async {
            final completer = Completer<int>();
            final bloc = completer.future.toAsyncBlocSignal();

            await bloc.close();
            expect(bloc.signal.disposed, isTrue);

            completer.complete(42);
            await Future<void>.delayed(Duration.zero);

            expect(bloc.stateValue, isA<AsyncLoading<int>>());
          },
          (error, stackTrace) {
            uncaughtErrors.add(error);
          },
        );

        expect(uncaughtErrors, isEmpty);
      },
    );

    test(
      '(Issue #470) pending Future settling with error after close() does not '
      'throw SignalsWriteAfterDisposeError or unhandled async error',
      () async {
        final uncaughtErrors = <Object>[];
        await runZonedGuarded(
          () async {
            final completer = Completer<int>();
            final bloc = completer.future.toAsyncBlocSignal();

            await bloc.close();
            expect(bloc.signal.disposed, isTrue);

            completer.completeError(Exception('late error'));
            await Future<void>.delayed(Duration.zero);

            expect(bloc.stateValue, isA<AsyncLoading<int>>());
          },
          (error, stackTrace) {
            uncaughtErrors.add(error);
          },
        );

        expect(uncaughtErrors, isEmpty);
      },
    );

    test(
      '(Issue #470) closing Future.toAsyncBlocSignal(timeout: ...) before '
      'timeout elapses produces zero uncaught zone errors',
      () async {
        final uncaughtErrors = <Object>[];
        await runZonedGuarded(
          () async {
            final completer = Completer<int>();
            final bloc = completer.future.toAsyncBlocSignal(
              timeout: const Duration(milliseconds: 20),
            );

            await bloc.close();
            await Future<void>.delayed(const Duration(milliseconds: 50));
            expect(bloc.stateValue, isA<AsyncLoading<int>>());
          },
          (error, stackTrace) {
            uncaughtErrors.add(error);
          },
        );

        expect(uncaughtErrors, isEmpty);
      },
    );

    test(
      '(Issue #470) synchronous Future.then invocation does not throw '
      'LateInitializationError',
      () async {
        final syncFuture = _SynchronousFuture<int>(42);
        final bloc = syncFuture.toAsyncBlocSignal();
        await Future<void>.microtask(() {});

        expect(bloc.stateValue, isA<AsyncData<int>>());
        expect((bloc.stateValue as AsyncData<int>).value, equals(42));

        await bloc.close();
        // Calling close() a second time is idempotent
        await bloc.close();
      },
    );

    test(
      '(Issue #470) concurrent close() calls await shared _closeFuture and '
      'dispose owned signal',
      () async {
        final completer = Completer<int>();
        final bloc = completer.future.toAsyncBlocSignal();

        final f1 = bloc.close();
        final f2 = bloc.close();
        await f2;
        expect(bloc.signal.disposed, isTrue);
        await f1;
      },
    );

    test(
      '(Issue #470) synchronous re-entrant close() inside onClose returns '
      'identical shared close future and awaits signal disposal',
      () async {
        final previousObserver = BlocSignalObserver.observer;
        addTearDown(() => BlocSignalObserver.observer = previousObserver);

        final completer = Completer<int>();
        final bloc = completer.future.toAsyncBlocSignal();

        Future<void>? outerFuture;
        Future<void>? reentrantFuture;
        var disposedWhenReentrantCompleted = false;

        BlocSignalObserver.observer = _OnCloseCallbackObserver((closed) {
          if (identical(closed, bloc) && reentrantFuture == null) {
            reentrantFuture = bloc.close();
            unawaited(
              reentrantFuture!.whenComplete(() {
                disposedWhenReentrantCompleted = bloc.signal.disposed;
              }),
            );
          }
        });

        outerFuture = bloc.close();
        await outerFuture;

        expect(reentrantFuture, isNotNull);
        expect(identical(reentrantFuture, outerFuture), isTrue);
        await reentrantFuture;
        expect(disposedWhenReentrantCompleted, isTrue);
      },
    );

    test(
      '(Issue #470) early close() cancels pending timeout Timer immediately',
      () async {
        Timer? createdTimer;
        await runZoned(
          () async {
            final completer = Completer<int>();
            final bloc = completer.future.toAsyncBlocSignal(
              timeout: const Duration(seconds: 30),
            );
            expect(createdTimer, isNotNull);
            expect(createdTimer!.isActive, isTrue);

            await bloc.close();
            expect(createdTimer!.isActive, isFalse);
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              return createdTimer = parent.createTimer(zone, duration, f);
            },
          ),
        );
      },
    );

    test(
      '(Issue #470) settling with value or error before timeout cancels '
      'pending timeout Timer',
      () async {
        Timer? timer1;
        await runZoned(
          () async {
            final c1 = Completer<int>();
            final b1 = c1.future.toAsyncBlocSignal(
              timeout: const Duration(seconds: 30),
            );
            expect(timer1!.isActive, isTrue);
            c1.complete(7);
            await Future<void>.delayed(Duration.zero);
            expect(timer1!.isActive, isFalse);
            expect((b1.stateValue as AsyncData<int>).value, equals(7));
            await b1.close();
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              return timer1 = parent.createTimer(zone, duration, f);
            },
          ),
        );

        Timer? timer2;
        await runZoned(
          () async {
            final c2 = Completer<int>();
            final b2 = c2.future.toAsyncBlocSignal(
              timeout: const Duration(seconds: 30),
            );
            expect(timer2!.isActive, isTrue);
            c2.completeError(Exception('boom before timeout'));
            await Future<void>.delayed(Duration.zero);
            expect(timer2!.isActive, isFalse);
            expect(b2.stateValue, isA<AsyncError<int>>());
            await b2.close();
          },
          zoneSpecification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              return timer2 = parent.createTimer(zone, duration, f);
            },
          ),
        );
      },
    );
  });
}

class _SynchronousFuture<T> implements Future<T> {
  _SynchronousFuture(this._value);

  final T _value;

  @override
  Stream<T> asStream() => Stream<T>.value(_value);

  @override
  Future<T> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) =>
      this;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(T value) onValue, {
    Function? onError,
  }) {
    final result = onValue(_value);
    if (result is Future<R>) return result;
    return _SynchronousFuture<R>(result);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      this;

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    final result = action();
    if (result is Future<void>) {
      unawaited(result);
    }
    return this;
  }
}

class _OnCloseCallbackObserver extends BlocSignalObserver {
  _OnCloseCallbackObserver(this._onClose);

  final void Function(BlocSignalBase<dynamic> bloc) _onClose;

  @override
  void onClose(BlocSignalBase<dynamic> bloc) => _onClose(bloc);
}
