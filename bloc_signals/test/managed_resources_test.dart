import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart'
    show EffectOptions, ReadonlySignal, Signal, signal;
import 'package:test/test.dart';

class _RecordingObserver extends BlocSignalObserver {
  int closeCount = 0;
  final List<Object> errors = <Object>[];

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);
    closeCount++;
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    errors.add(error);
  }
}

class _ThrowingOnErrorObserver extends BlocSignalObserver {
  _ThrowingOnErrorObserver(this.errorToThrow);

  final Error errorToThrow;
  int closeCount = 0;

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    throw errorToThrow;
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);
    closeCount++;
  }
}

class _ResourceCubit extends CubitSignal<int> {
  _ResourceCubit() : super(initialState: 0);

  final List<Object> localErrors = <Object>[];

  R track<R>(R resource, FutureOr<void> Function(R resource) onDispose) =>
      manageResource<R>(resource, onDispose);

  StreamSubscription<S> trackSubscription<S>(
    StreamSubscription<S> subscription,
  ) =>
      manageStreamSubscription<S>(subscription);

  Timer trackTimer(Timer timer) => manageTimer(timer);

  void Function() trackEffect(
    void Function() callback, {
    void Function()? onDispose,
  }) =>
      createEffect(callback, onDispose: onDispose);

  @override
  void onError(Object error, StackTrace stackTrace) {
    localErrors.add(error);
    super.onError(error, stackTrace);
  }
}

class _ResourceBloc extends BlocSignal<String, int> {
  _ResourceBloc() : super(initialState: 0) {
    on<String>((event, emit) => emit(value + 1));
  }

  R track<R>(R resource, FutureOr<void> Function(R resource) onDispose) =>
      manageResource<R>(resource, onDispose);

  StreamSubscription<S> trackSubscription<S>(
    StreamSubscription<S> subscription,
  ) =>
      manageStreamSubscription<S>(subscription);

  Timer trackTimer(Timer timer) => manageTimer(timer);
}

class _FakeResource {
  _FakeResource(this.id);

  final String id;
  bool disposed = false;
}

class _DirectBaseContainer extends BlocSignalBase<int> {
  _DirectBaseContainer() : _state = signal<int>(0);

  final Signal<int> _state;
  bool _closed = false;

  R track<R>(R resource, FutureOr<void> Function(R resource) onDispose) =>
      manageResource<R>(resource, onDispose);

  StreamSubscription<S> trackSubscription<S>(
    StreamSubscription<S> subscription,
  ) =>
      manageStreamSubscription<S>(subscription);

  Timer trackTimer(Timer timer) => manageTimer(timer);

  void Function() trackEffect(
    void Function() callback, {
    void Function()? onDispose,
  }) =>
      createEffect(callback, onDispose: onDispose);

  @override
  bool get isClosed => _closed;

  @override
  ReadonlySignal<int> get state => _state;

  @override
  int get value => _state.value;

  @override
  int get stateValue => _state.value;

  @override
  bool equals(int previous, int current) => previous == current;

  @override
  Object get zoneEventKey => Object();

  @override
  Object get zoneBlocKey => BlocSignalBase.ambientZoneBlocKey;

  @override
  void emit(int newState) {
    _state.value = newState;
  }

  @override
  void handleTransition(Object event, int oldState, int newState) {}

  @override
  void onChange(Change<int> change) {}

  @override
  void onError(Object error, StackTrace stackTrace) {}

  @override
  void emitError(Object error, [StackTrace? stackTrace]) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  void emitTelemetry(
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {}

  @override
  void onTelemetry(
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {}

  @override
  void Function() createEffect(
    void Function() callback, {
    EffectOptions? options,
    void Function()? onDispose,
  }) =>
      () {};

  @override
  Future<void> close() async {
    _closed = true;
    _state.dispose();
  }

  @override
  bool get isHistorySuppressed => false;

  @override
  void runWithoutHistory(void Function() action) => action();
}

class _DelegatingBaseContainer extends _DirectBaseContainer {
  final List<FutureOr<void> Function()> _disposers =
      <FutureOr<void> Function()>[];

  @override
  R manageResource<R>(
    R resource,
    FutureOr<void> Function(R resource) onDispose,
  ) {
    _disposers.add(() => onDispose(resource));
    return resource;
  }

  @override
  Future<void> close() async {
    for (final disposer in _disposers.reversed) {
      await disposer();
    }
    await super.close();
  }
}

void main() {
  group('Managed resource registration (Issue #394)', () {
    late BlocSignalObserver? previousObserver;
    late _RecordingObserver observer;

    setUp(() {
      previousObserver = BlocSignalObserver.observer;
      observer = _RecordingObserver();
      BlocSignalObserver.observer = observer;
    });

    tearDown(() {
      BlocSignalObserver.observer = previousObserver;
    });

    test('manageTimer and manageStreamSubscription auto-cancel on CubitSignal',
        () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      var timerFired = false;
      final timer = cubit.trackTimer(
        Timer(const Duration(milliseconds: 50), () {
          timerFired = true;
        }),
      );

      final received = <int>[];
      final sub = cubit.trackSubscription(
        controller.stream.listen(received.add),
      );

      controller.add(1);
      await Future<void>.microtask(() {});
      expect(received, [1]);
      expect(timer.isActive, isTrue);

      await cubit.close();

      expect(timer.isActive, isFalse);
      expect(timerFired, isFalse);

      // Post-close events should not be delivered to the cancelled
      // subscription.
      controller.add(2);
      await Future<void>.microtask(() {});
      expect(received, [1]);

      // Cancelling an already-cancelled subscription is safe.
      await sub.cancel();
    });

    test('manageTimer and manageStreamSubscription auto-cancel on BlocSignal',
        () async {
      final bloc = _ResourceBloc();
      addTearDown(bloc.close);

      final controller = StreamController<String>();
      addTearDown(controller.close);

      final timer = bloc.trackTimer(
        Timer.periodic(const Duration(milliseconds: 20), (_) {}),
      );
      final received = <String>[];
      bloc.trackSubscription(controller.stream.listen(received.add));

      controller.add('a');
      await Future<void>.microtask(() {});
      expect(received, ['a']);
      expect(timer.isActive, isTrue);

      await bloc.close();

      expect(timer.isActive, isFalse);
      controller.add('b');
      await Future<void>.microtask(() {});
      expect(received, ['a']);
    });

    test(
        'manageResource returns the registered resource and disposes in '
        'reverse (LIFO) order', () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final order = <String>[];
      final first = _FakeResource('first');
      final second = _FakeResource('second');
      final third = _FakeResource('third');

      final returnedFirst = cubit.track(first, (r) {
        r.disposed = true;
        order.add(r.id);
      });
      final returnedSecond = cubit.track(second, (r) async {
        await Future<void>.microtask(() {});
        r.disposed = true;
        order.add(r.id);
      });
      final returnedThird = cubit.track(third, (r) {
        r.disposed = true;
        order.add(r.id);
      });

      expect(identical(returnedFirst, first), isTrue);
      expect(identical(returnedSecond, second), isTrue);
      expect(identical(returnedThird, third), isTrue);
      expect(order, isEmpty);

      await cubit.close();

      expect(first.disposed, isTrue);
      expect(second.disposed, isTrue);
      expect(third.disposed, isTrue);
      expect(order, ['third', 'second', 'first']);
    });

    test(
        'sequential and concurrent close() calls are idempotent and await '
        'shared async teardown', () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final completer = Completer<void>();
      var disposeCount = 0;

      cubit.track('async-resource', (_) async {
        disposeCount++;
        await completer.future;
      });

      final future1 = cubit.close();
      final future2 = cubit.close();

      expect(cubit.isClosed, isTrue);
      expect(disposeCount, 1);
      expect(observer.closeCount, 0);

      completer.complete();
      await Future.wait<void>([future1, future2]);

      expect(disposeCount, 1);
      expect(observer.closeCount, 1);

      // Subsequent sequential close() is also a no-op.
      await cubit.close();
      expect(disposeCount, 1);
      expect(observer.closeCount, 1);
    });

    test(
        'faulty sync and async disposers throwing Exception route to onError '
        'without aborting remaining disposers or observer.onClose', () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final disposed = <String>[];
      const syncException = FormatException('sync boom');
      final asyncException = TimeoutException('async boom');

      cubit
        ..track('first', disposed.add)
        ..track('bad-async', (_) async {
          await Future<void>.microtask(() {});
          throw asyncException;
        })
        ..track('bad-sync', (_) {
          throw syncException;
        })
        ..track('last', disposed.add);

      await cubit.close();

      expect(disposed, ['last', 'first']);
      expect(cubit.localErrors, [syncException, asyncException]);
      expect(observer.errors, [syncException, asyncException]);
      expect(observer.closeCount, 1);
    });

    test(
        'fatal Error thrown by a disposer still drains remaining disposers '
        'and observer.onClose, then rethrows', () async {
      final cubit = _ResourceCubit();

      final disposed = <String>[];
      final fatalError = StateError('fatal disposer error');

      cubit
        ..track('first', disposed.add)
        ..track('fatal', (_) => throw fatalError)
        ..track('last', disposed.add);

      await expectLater(cubit.close(), throwsA(same(fatalError)));

      expect(disposed, ['last', 'first']);
      expect(observer.closeCount, 1);
    });

    test(
        'calling manageResource, manageStreamSubscription, or manageTimer '
        'after close() immediately disposes the resource and guards errors',
        () async {
      final cubit = _ResourceCubit();
      await cubit.close();

      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      const syncException = FormatException('post-close sync');
      final asyncException = TimeoutException('post-close async');

      final resource = _FakeResource('late');
      final returned = cubit.track(resource, (r) {
        r.disposed = true;
      });
      expect(identical(returned, resource), isTrue);
      expect(resource.disposed, isTrue);

      final timer = cubit.trackTimer(
        Timer(const Duration(seconds: 10), () {}),
      );
      expect(timer.isActive, isFalse);

      final received = <int>[];
      cubit.trackSubscription(controller.stream.listen(received.add));
      controller.add(42);
      await Future<void>.microtask(() {});
      expect(received, isEmpty);

      // Guarded sync exception post-close.
      cubit.track('sync-fail', (_) => throw syncException);
      expect(cubit.localErrors, contains(syncException));

      // Guarded async exception post-close.
      cubit.track('async-fail', (_) async {
        await Future<void>.microtask(() {});
        throw asyncException;
      });
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});
      expect(cubit.localErrors, contains(asyncException));
    });

    test(
        'reentrant manageResource inside a disposer during close() disposes '
        'immediately without ConcurrentModificationError', () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final reentrantResource = _FakeResource('reentrant');
      final order = <String>[];

      cubit
        ..track('outer-first', order.add)
        ..track('outer-spawner', (r) {
          order.add(r);
          cubit.track(reentrantResource, (nested) {
            nested.disposed = true;
            order.add(nested.id);
          });
        });

      await cubit.close();

      expect(reentrantResource.disposed, isTrue);
      expect(order, ['outer-spawner', 'reentrant', 'outer-first']);
      expect(observer.closeCount, 1);
    });

    test(
        'direct BlocSignalBase subclass without CubitSignalMixin falls back '
        'cleanly to returning resource', () async {
      final direct = _DirectBaseContainer();
      addTearDown(direct.close);

      final resource = _FakeResource('direct');
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);
      final sub = controller.stream.listen((_) {});
      addTearDown(sub.cancel);
      final timer = Timer(const Duration(seconds: 10), () {});
      addTearDown(timer.cancel);

      expect(identical(direct.track(resource, (_) {}), resource), isTrue);
      expect(identical(direct.trackSubscription(sub), sub), isTrue);
      expect(identical(direct.trackTimer(timer), timer), isTrue);
      expect(resource.disposed, isFalse);

      await direct.close();
      expect(direct.isClosed, isTrue);

      var cancelled = false;
      final delegatingController = StreamController<int>(
        onCancel: () {
          cancelled = true;
        },
      );
      addTearDown(delegatingController.close);

      final delegating = _DelegatingBaseContainer();
      addTearDown(delegating.close);
      delegating.trackSubscription(
        delegatingController.stream.listen((_) {}),
      );
      final delegatingTimer = delegating.trackTimer(
        Timer(const Duration(seconds: 10), () {}),
      );
      await delegating.close();
      expect(cancelled, isTrue);
      expect(delegatingTimer.isActive, isFalse);
    });

    test(
        'post-close async disposer returning non-void Future<bool> routes '
        'Exception to onError without Zone TypeError (Issue #394: BLOCKER-1)',
        () async {
      final cubit = _ResourceCubit();
      await cubit.close();

      final zoneErrors = <Object>[];
      const asyncException = FormatException('non-void future boom');

      await runZonedGuarded(
        () async {
          cubit.track<String>('non-void', (_) async {
            await Future<void>.microtask(() {});
            throw asyncException;
          });
          // Explicit Future<bool> disposer return type to exercise covariance.
          Future<bool> boolDisposer(String _) async {
            await Future<void>.microtask(() {});
            throw asyncException;
          }

          cubit.track<String>('bool-future', boolDisposer);
          await Future<void>.microtask(() {});
          await Future<void>.microtask(() {});
        },
        (error, _) => zoneErrors.add(error),
      );

      expect(zoneErrors, isEmpty);
      expect(cubit.localErrors, [asyncException, asyncException]);
    });

    test(
        'effect onDispose Exception routes to onError and does not abort '
        'remaining effects, managed resources, or observer.onClose '
        '(Issue #394: BLOCKER-2)', () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final order = <String>[];
      const effectException = FormatException('effect boom');

      cubit
        ..trackEffect(
          () {},
          onDispose: () => throw effectException,
        )
        ..trackEffect(
          () {},
          onDispose: () => order.add('effect-2'),
        )
        ..track('managed', order.add);

      await cubit.close();

      expect(order, ['effect-2', 'managed']);
      expect(cubit.localErrors, [effectException]);
      expect(observer.closeCount, 1);
    });

    test(
        'effect onDispose fatal Error still drains remaining effects, '
        'managed resources, and observer.onClose, then rethrows '
        '(Issue #394: BLOCKER-2)', () async {
      final cubit = _ResourceCubit();

      final order = <String>[];
      final fatalError = StateError('fatal effect error');

      cubit
        ..trackEffect(
          () {},
          onDispose: () => throw fatalError,
        )
        ..trackEffect(
          () {},
          onDispose: () => order.add('effect-2'),
        )
        ..track('managed', order.add);

      await expectLater(cubit.close(), throwsA(same(fatalError)));

      expect(order, ['effect-2', 'managed']);
      expect(observer.closeCount, 1);
    });

    test(
        'manageResource called while close() is suspended across an await '
        'disposes immediately (Issue #394)', () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final gate = Completer<void>();
      final lateResource = _FakeResource('during-await');

      cubit.track('async-blocker', (_) => gate.future);

      final closeFuture = cubit.close();
      expect(cubit.isClosed, isTrue);

      cubit.track(lateResource, (r) {
        r.disposed = true;
      });
      expect(lateResource.disposed, isTrue);

      gate.complete();
      await closeFuture;
      expect(observer.closeCount, 1);
    });

    test(
        'async fatal Error and multiple fatal Errors preserve firstFatalError '
        'after draining all disposers and observer.onClose (Issue #394)',
        () async {
      final cubit = _ResourceCubit();

      final disposed = <String>[];
      final firstError = StateError('first async fatal');
      final secondError = StateError('second sync fatal');

      cubit
        ..track('tail', disposed.add)
        ..track('second', (_) => throw secondError)
        ..track('first', (_) async {
          await Future<void>.microtask(() {});
          throw firstError;
        });

      await expectLater(cubit.close(), throwsA(same(firstError)));

      expect(disposed, ['tail']);
      expect(observer.closeCount, 1);
    });

    test(
        'throwing onError during close() drains remaining disposers and '
        'observer.onClose, resets _closeFuture, and settles cleanly on '
        'subsequent close() (Issue #394: BLOCKER-1)', () async {
      final fatalOnError = StateError('observer onError exploded');
      final throwingObserver = _ThrowingOnErrorObserver(fatalOnError);
      BlocSignalObserver.observer = throwingObserver;

      final cubit = _ResourceCubit();
      final disposed = <String>[];

      cubit
        ..track('tail', disposed.add)
        ..track('bad', (_) => throw const FormatException('boom'));

      await expectLater(cubit.close(), throwsA(same(fatalOnError)));

      expect(disposed, ['tail']);
      expect(throwingObserver.closeCount, 1);

      // Subsequent close() must settle cleanly instead of deadlocking or
      // rethrowing.
      await cubit.close();
    });

    test(
        'concurrent close() calls share an async fatal Error rejection '
        '(Issue #394)', () async {
      final cubit = _ResourceCubit();
      final gate = Completer<void>();
      final fatalError = StateError('concurrent async fatal');

      cubit.track('async-fatal', (_) async {
        await gate.future;
        throw fatalError;
      });

      final future1 = cubit.close();
      final future2 = cubit.close();

      gate.complete();
      await expectLater(future1, throwsA(same(fatalError)));
      await expectLater(future2, throwsA(same(fatalError)));
      expect(observer.closeCount, 1);

      // Subsequent sequential close() settles cleanly.
      await cubit.close();
    });

    test(
        'manageResource called mid-await during close() routes recoverable '
        'Exception to onError without aborting teardown (Issue #394)',
        () async {
      final cubit = _ResourceCubit();
      addTearDown(cubit.close);

      final gate = Completer<void>();
      const midCloseException = FormatException('mid-close boom');

      cubit.track('async-blocker', (_) => gate.future);

      final closeFuture = cubit.close();
      cubit.track('mid-close-fail', (_) => throw midCloseException);

      gate.complete();
      await closeFuture;

      expect(cubit.localErrors, [midCloseException]);
      expect(observer.closeCount, 1);
    });
  });
}
