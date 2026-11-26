// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

sealed class _TestEvent {}

final class _WorkEvent extends _TestEvent {
  _WorkEvent(this.id, {this.completer, this.error, this.syncError = false});

  final int id;
  final Completer<void>? completer;
  final Exception? error;
  final bool syncError;
}

class _TelemetryAndErrorObserver extends BlocSignalObserver {
  final List<({String name, Object? event, Map<String, dynamic>? metadata})>
      telemetry = [];
  final List<Object> errors = [];
  final List<Object?> completedEvents = [];
  final List<({Object? event, Object? state})> transitions = [];

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    transitions.add((event: event, state: state));
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    telemetry.add((name: name, event: event, metadata: metadata));
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    completedEvents.add(event);
  }
}

class _ConcurrentBloc extends BlocSignal<_TestEvent, List<int>> {
  _ConcurrentBloc() : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) async {
        if (event.syncError) {
          throw event.error ?? Exception('sync error');
        }
        if (event.completer != null) {
          await event.completer!.future;
        }
        if (event.error != null) {
          throw event.error!;
        }
        emit([...stateValue, event.id]);
      },
      transformer: concurrent(),
    );
  }
}

class _DebounceBloc extends BlocSignal<_TestEvent, List<int>> {
  _DebounceBloc(Duration duration) : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) async {
        if (event.syncError) {
          throw event.error ?? Exception('sync error');
        }
        if (event.completer != null) {
          await event.completer!.future;
        }
        if (event.error != null) {
          throw event.error!;
        }
        executedIds.add(event.id);
        emit([...stateValue, event.id]);
      },
      transformer: debounce(duration),
    );
  }

  final List<int> executedIds = [];
}

class _SyncDebounceBloc extends BlocSignal<_TestEvent, List<int>> {
  _SyncDebounceBloc(Duration duration) : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) {
        if (event.syncError) {
          throw event.error ?? Exception('sync error');
        }
        emit([...stateValue, event.id]);
      },
      transformer: debounce(duration),
    );
  }
}

class _ThrottleBloc extends BlocSignal<_TestEvent, List<int>> {
  _ThrottleBloc(Duration duration, {bool trailing = false})
      : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) async {
        if (event.syncError) {
          throw event.error ?? Exception('sync error');
        }
        if (event.completer != null) {
          await event.completer!.future;
        }
        if (event.error != null) {
          throw event.error!;
        }
        executedIds.add(event.id);
        emit([...stateValue, event.id]);
      },
      transformer: throttle(duration, trailing: trailing),
    );
  }

  final List<int> executedIds = [];
}

class _SyncThrottleBloc extends BlocSignal<_TestEvent, List<int>> {
  _SyncThrottleBloc(Duration duration, {bool trailing = false})
      : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) {
        if (event.syncError) {
          throw event.error ?? Exception('sync error');
        }
        emit([...stateValue, event.id]);
      },
      transformer: throttle(duration, trailing: trailing),
    );
  }
}

void main() {
  late _TelemetryAndErrorObserver observer;
  BlocSignalObserver? previousObserver;

  setUp(() {
    previousObserver = BlocSignalObserver.observer;
    observer = _TelemetryAndErrorObserver();
    BlocSignalObserver.observer = observer;
  });

  tearDown(() {
    BlocSignalObserver.observer = previousObserver;
  });

  group('(Issue #480: concurrent)', () {
    test('processes overlapping async events concurrently out-of-order',
        () async {
      final bloc = _ConcurrentBloc();
      addTearDown(bloc.close);

      final slow = Completer<void>();
      final fast = Completer<void>();

      bloc.add(_WorkEvent(1, completer: slow));
      bloc.add(_WorkEvent(2, completer: fast));
      await Future<void>.microtask(() {});

      fast.complete();
      await Future<void>.microtask(() {});
      expect(bloc.stateValue, equals([2]));

      slow.complete();
      await Future<void>.microtask(() {});
      expect(bloc.stateValue, equals([2, 1]));
      expect(observer.completedEvents, hasLength(2));
    });

    test('guards post-close emit without throwing AssertionError', () async {
      final bloc = _ConcurrentBloc();
      final completer = Completer<void>();

      bloc.add(_WorkEvent(1, completer: completer));
      await Future<void>.microtask(() {});

      await bloc.close();
      completer.complete();
      await Future<void>.microtask(() {});

      expect(bloc.stateValue, isEmpty);
      expect(observer.errors, isEmpty);
    });

    test('routes sync and async errors to onError and fires onEventCompleted',
        () async {
      final bloc = _ConcurrentBloc();
      addTearDown(bloc.close);

      final asyncErr = Exception('async failure');
      final syncErr = Exception('sync failure');
      final completer = Completer<void>();

      final e1 = _WorkEvent(1, completer: completer, error: asyncErr);
      final e2 = _WorkEvent(2, syncError: true, error: syncErr);

      bloc.add(e1);
      bloc.add(e2);
      await Future<void>.microtask(() {});

      expect(observer.errors, contains(syncErr));
      expect(observer.completedEvents, contains(e2));

      completer.complete();
      await Future<void>.microtask(() {});

      expect(observer.errors, containsAll([syncErr, asyncErr]));
      expect(observer.completedEvents, containsAll([e1, e2]));
    });

    test('no-ops when container is already closed', () async {
      final bloc = _ConcurrentBloc();
      await bloc.close();

      var invoked = false;
      final transformer = concurrent<_WorkEvent, List<int>>(bloc: bloc);
      final result = transformer(
        _WorkEvent(1),
        (event, emit) => invoked = true,
        (_) {},
      );
      expect(result, isNull);
      expect(invoked, isFalse);
    });
  });

  group('(Issue #480: debounce)', () {
    test('coalesces rapid burst and emits eventDropped for superseded events',
        () async {
      final bloc = _DebounceBloc(const Duration(milliseconds: 30));
      addTearDown(bloc.close);

      final e1 = _WorkEvent(1);
      final e2 = _WorkEvent(2);
      final e3 = _WorkEvent(3);

      bloc.add(e1);
      bloc.add(e2);
      bloc.add(e3);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(bloc.executedIds, equals([3]));
      expect(bloc.stateValue, equals([3]));
      expect(observer.completedEvents, containsAll([e1, e2, e3]));

      final dropped = observer.telemetry
          .where((t) => t.name == BlocTelemetryKeys.eventDropped)
          .toList();
      expect(dropped, hasLength(2));
      expect(dropped[0].event, same(e1));
      expect(
        dropped[0].metadata,
        equals({'transformer': 'debounce', 'reason': 'coalesced'}),
      );
      expect(dropped[1].event, same(e2));
    });

    test('executes sequential bursts separated by more than duration',
        () async {
      final bloc = _DebounceBloc(const Duration(milliseconds: 20));
      addTearDown(bloc.close);

      bloc.add(_WorkEvent(1));
      bloc.add(_WorkEvent(2));
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(bloc.stateValue, equals([2]));

      bloc.add(_WorkEvent(3));
      bloc.add(_WorkEvent(4));
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(bloc.stateValue, equals([2, 4]));
    });

    test('routes sync and async handler errors to onError and onEventCompleted',
        () async {
      final syncBloc = _SyncDebounceBloc(const Duration(milliseconds: 15));
      addTearDown(syncBloc.close);

      final syncErr = Exception('sync debounce failure');
      final eSync = _WorkEvent(1, syncError: true, error: syncErr);
      syncBloc.add(eSync);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(observer.errors, contains(syncErr));
      expect(observer.completedEvents, contains(eSync));

      final asyncBloc = _DebounceBloc(const Duration(milliseconds: 15));
      addTearDown(asyncBloc.close);

      final asyncErr = Exception('async debounce failure');
      final eAsync = _WorkEvent(2, error: asyncErr);
      asyncBloc.add(eAsync);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(observer.errors, contains(asyncErr));
      expect(observer.completedEvents, contains(eAsync));
    });

    test('await bloc.close() cancels pending timer and completes cleanly',
        () async {
      final bloc = _DebounceBloc(const Duration(milliseconds: 100));
      final e1 = _WorkEvent(1);

      bloc.add(e1);
      await bloc.close();

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(bloc.executedIds, isEmpty);
      expect(bloc.stateValue, isEmpty);
      expect(observer.completedEvents, contains(e1));
      expect(observer.errors, isEmpty);
    });

    test('executes synchronous debounce handler cleanly', () async {
      final bloc = _SyncDebounceBloc(const Duration(milliseconds: 15));
      addTearDown(bloc.close);

      final e1 = _WorkEvent(1);
      bloc.add(e1);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bloc.stateValue, equals([1]));
      expect(observer.completedEvents, contains(e1));
    });

    test('no-ops when container is already closed with explicit bloc',
        () async {
      final bloc = _DebounceBloc(const Duration(milliseconds: 20));
      await bloc.close();

      var invoked = false;
      final transformer = debounce<_WorkEvent, List<int>>(
        const Duration(milliseconds: 20),
        bloc: bloc,
      );
      final result = transformer(
        _WorkEvent(1),
        (event, emit) => invoked = true,
        (_) {},
      );
      expect(result, isNull);
      expect(invoked, isFalse);
    });
  });

  group('(Issue #480: throttle)', () {
    test(
        'leading-only (trailing: false) executes first and drops mid-cooldown '
        'events', () async {
      final bloc = _ThrottleBloc(const Duration(milliseconds: 40));
      addTearDown(bloc.close);

      final e1 = _WorkEvent(1);
      final e2 = _WorkEvent(2);
      final e3 = _WorkEvent(3);

      bloc.add(e1);
      bloc.add(e2);
      bloc.add(e3);
      await Future<void>.microtask(() {});

      expect(bloc.executedIds, equals([1]));
      expect(bloc.stateValue, equals([1]));

      final dropped = observer.telemetry
          .where((t) => t.name == BlocTelemetryKeys.eventDropped)
          .toList();
      expect(dropped, hasLength(2));
      expect(dropped[0].event, same(e2));
      expect(
        dropped[0].metadata,
        equals({'transformer': 'throttle', 'reason': 'throttled'}),
      );
      expect(dropped[1].event, same(e3));

      // After cooldown expires, next event executes immediately.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final e4 = _WorkEvent(4);
      bloc.add(e4);
      await Future<void>.microtask(() {});

      expect(bloc.executedIds, equals([1, 4]));
      expect(bloc.stateValue, equals([1, 4]));
    });

    test(
        'trailing: true executes leading, coalesces mid-cooldown, and runs '
        'latest on expiry', () async {
      final bloc = _ThrottleBloc(
        const Duration(milliseconds: 35),
        trailing: true,
      );
      addTearDown(bloc.close);

      final e1 = _WorkEvent(1);
      final e2 = _WorkEvent(2);
      final e3 = _WorkEvent(3);

      bloc.add(e1);
      bloc.add(e2);
      bloc.add(e3);
      await Future<void>.microtask(() {});

      expect(bloc.executedIds, equals([1]));

      // e2 was superseded by e3 in the trailing slot.
      final dropped = observer.telemetry
          .where((t) => t.name == BlocTelemetryKeys.eventDropped)
          .toList();
      expect(dropped, hasLength(1));
      expect(dropped[0].event, same(e2));
      expect(
        dropped[0].metadata,
        equals({'transformer': 'throttle', 'reason': 'coalesced'}),
      );

      // Wait for cooldown to expire and trailing e3 to execute.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.executedIds, equals([1, 3]));
      expect(bloc.stateValue, equals([1, 3]));
      expect(observer.completedEvents, containsAll([e1, e2, e3]));
    });

    test('bloc.close() cancels cooldown timer and resolves queued trailing',
        () async {
      final bloc = _ThrottleBloc(
        const Duration(milliseconds: 100),
        trailing: true,
      );

      final e1 = _WorkEvent(1);
      final e2 = _WorkEvent(2);

      bloc.add(e1);
      bloc.add(e2);
      await Future<void>.microtask(() {});
      expect(bloc.executedIds, equals([1]));

      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(bloc.executedIds, equals([1]));
      expect(observer.completedEvents, containsAll([e1, e2]));
      expect(observer.errors, isEmpty);
    });

    test('routes sync and async handler errors to onError (leading & trailing)',
        () async {
      final syncBloc = _SyncThrottleBloc(
        const Duration(milliseconds: 25),
        trailing: true,
      );
      addTearDown(syncBloc.close);

      final leadErr = Exception('leading sync err');
      final trailErr = Exception('trailing sync err');
      final e1 = _WorkEvent(1, syncError: true, error: leadErr);
      final e2 = _WorkEvent(2, syncError: true, error: trailErr);

      syncBloc.add(e1);
      syncBloc.add(e2);
      await Future<void>.microtask(() {});
      expect(observer.errors, contains(leadErr));
      expect(observer.completedEvents, contains(e1));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observer.errors, containsAll([leadErr, trailErr]));
      expect(observer.completedEvents, containsAll([e1, e2]));

      final asyncBloc = _ThrottleBloc(
        const Duration(milliseconds: 25),
        trailing: true,
      );
      addTearDown(asyncBloc.close);
      final asyncTrailErr = Exception('trailing async err');
      asyncBloc.add(_WorkEvent(3));
      final e4 = _WorkEvent(4, error: asyncTrailErr);
      asyncBloc.add(e4);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observer.errors, contains(asyncTrailErr));
      expect(observer.completedEvents, contains(e4));
    });

    test('executes synchronous trailing throttle handler cleanly', () async {
      final bloc = _SyncThrottleBloc(
        const Duration(milliseconds: 20),
        trailing: true,
      );
      addTearDown(bloc.close);

      final e1 = _WorkEvent(1);
      final e2 = _WorkEvent(2);
      bloc.add(e1);
      bloc.add(e2);
      await Future<void>.microtask(() {});
      expect(bloc.stateValue, equals([1]));

      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(bloc.stateValue, equals([1, 2]));
      expect(observer.completedEvents, containsAll([e1, e2]));
    });

    test('no-ops when container is already closed with explicit bloc',
        () async {
      final bloc = _ThrottleBloc(const Duration(milliseconds: 20));
      await bloc.close();

      var invoked = false;
      final transformer = throttle<_WorkEvent, List<int>>(
        const Duration(milliseconds: 20),
        bloc: bloc,
      );
      final result = transformer(
        _WorkEvent(1),
        (event, emit) => invoked = true,
        (_) {},
      );
      expect(result, isNull);
      expect(invoked, isFalse);
    });

    test('registerCloseCallback invokes immediately when already closed',
        () async {
      final bloc = _ThrottleBloc(const Duration(milliseconds: 20));
      await bloc.close();

      var called = false;
      bloc.registerCloseCallback(() => called = true);
      expect(called, isTrue);

      final minimal = _MinimalNoOpBloc();
      minimal.registerCloseCallback(() {});
    });
  });

  group('(Issue #480: Round 1 Blocker Regressions)', () {
    test(
      '(Issue #480: BLOCKER-1) throttle(trailing: true) attributes '
      'Transition.event to trailing event rather than leading event',
      () async {
        final bloc = _ThrottleBloc(
          const Duration(milliseconds: 30),
          trailing: true,
        );
        addTearDown(bloc.close);

        final lead = _WorkEvent(1);
        final trail = _WorkEvent(2);
        bloc.add(lead);
        bloc.add(trail);

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(bloc.stateValue, equals([1, 2]));
        expect(observer.transitions, hasLength(2));
        expect(observer.transitions[0].event, same(lead));
        expect(observer.transitions[1].event, same(trail));
      },
    );

    test(
      '(Issue #480: BLOCKER-3) reentrant onTelemetry calling bloc.close() '
      'during superseding debounce and throttle does not throw or arm timers',
      () async {
        final prev = BlocSignalObserver.observer;
        final reentrantObserver = _ReentrantCloseOnTelemetryObserver();
        BlocSignalObserver.observer = reentrantObserver;
        addTearDown(() => BlocSignalObserver.observer = prev);

        final debouncedBloc = _DebounceBloc(const Duration(milliseconds: 25));
        debouncedBloc.add(_WorkEvent(1));
        debouncedBloc.add(_WorkEvent(2));

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(debouncedBloc.isClosed, isTrue);
        expect(debouncedBloc.executedIds, isEmpty);
        expect(reentrantObserver.errors, isEmpty);

        final throttledBloc = _ThrottleBloc(
          const Duration(milliseconds: 25),
          trailing: true,
        );
        throttledBloc.add(_WorkEvent(1));
        throttledBloc.add(_WorkEvent(2));
        throttledBloc.add(_WorkEvent(3));

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(throttledBloc.isClosed, isTrue);
        expect(throttledBloc.executedIds, equals([1]));
        expect(reentrantObserver.errors, isEmpty);
      },
    );

    test(
      '(Issue #480: BLOCKER-3) reentrant onTelemetry calling bloc.add() '
      'during superseding debounce does not throw or leak',
      () async {
        final prev = BlocSignalObserver.observer;
        final reentrantObserver = _ReentrantAddOnTelemetryObserver(
          () => _WorkEvent(99),
        );
        BlocSignalObserver.observer = reentrantObserver;
        addTearDown(() => BlocSignalObserver.observer = prev);

        final bloc = _DebounceBloc(const Duration(milliseconds: 25));
        addTearDown(bloc.close);

        bloc.add(_WorkEvent(1));
        bloc.add(_WorkEvent(2));

        await Future<void>.delayed(const Duration(milliseconds: 70));
        expect(bloc.executedIds, equals([2]));
        expect(reentrantObserver.errors, isEmpty);
      },
    );

    test(
      '(Issue #480: BLOCKER-5) custom BlocSignalBase with no-op '
      'registerCloseCallback does not invoke handler or re-arm timer after '
      'isClosed becomes true',
      () async {
        final host = _MinimalNoOpBloc();

        var debounceInvoked = false;
        final debounced = debounce<_WorkEvent, int>(
          const Duration(milliseconds: 20),
          bloc: host,
        );
        final debounceFuture = debounced(
          _WorkEvent(1),
          (event, emit) => debounceInvoked = true,
          (_) {},
        );
        host.isClosed = true;
        await debounceFuture;
        expect(debounceInvoked, isFalse);

        host.isClosed = false;
        var throttleCount = 0;
        final throttled = throttle<_WorkEvent, int>(
          const Duration(milliseconds: 20),
          trailing: true,
          bloc: host,
        );
        await throttled(
          _WorkEvent(1),
          (event, emit) => throttleCount++,
          (_) {},
        );
        final trailingFuture = throttled(
          _WorkEvent(2),
          (event, emit) => throttleCount++,
          (_) {},
        );
        host.isClosed = true;
        await trailingFuture;
        expect(throttleCount, equals(1));
      },
    );

    test(
      '(Issue #480: Round 3 BLOCKER-1) throttle creates leading and trailing '
      'cooldown timers inside caller ZoneSpecification',
      () async {
        var timerCreateCount = 0;
        final createdInCustomZone = <bool>[];
        final markerKey = Object();
        final customZone = Zone.current.fork(
          zoneValues: {markerKey: true},
          specification: ZoneSpecification(
            createTimer: (self, parent, zone, duration, f) {
              timerCreateCount++;
              createdInCustomZone.add(zone[markerKey] == true);
              return parent.createTimer(zone, duration, f);
            },
          ),
        );

        await customZone.run(() async {
          final bloc = _ThrottleBloc(
            const Duration(milliseconds: 20),
            trailing: true,
          );
          addTearDown(bloc.close);

          bloc.add(_WorkEvent(1));
          bloc.add(_WorkEvent(2));

          await Future<void>.delayed(const Duration(milliseconds: 60));
          expect(bloc.executedIds, equals([1, 2]));
        });

        expect(timerCreateCount, greaterThanOrEqualTo(2));
        expect(createdInCustomZone, everyElement(isTrue));
      },
    );
  });

  group('(Issue #498: restartable cancellation token)', () {
    test('top-level helpers are safe no-ops outside a cancelable handler', () {
      expect(CancellationToken.current, isNull);
      expect(isCanceled, isFalse);
      onCancel(() {});
    });

    test(
      'isCanceled starts false and becomes true when superseded, suppressing '
      'late emit',
      () async {
        final bloc = _RestartableCancelBloc();
        addTearDown(bloc.close);

        final firstGate = Completer<void>();
        final secondGate = Completer<void>();

        bloc.add(_WorkEvent(1, completer: firstGate));
        await Future<void>.microtask(() {});

        expect(bloc.canceledSnapshots[1], isFalse);
        expect(bloc.tokens[1]?.isCanceled, isFalse);

        bloc.add(_WorkEvent(2, completer: secondGate));
        await Future<void>.microtask(() {});

        expect(bloc.tokens[1]?.isCanceled, isTrue);
        expect(bloc.tokens[2]?.isCanceled, isFalse);

        firstGate.complete();
        await Future<void>.microtask(() {});

        expect(bloc.postAwaitCanceledSnapshots[1], isTrue);
        expect(bloc.stateValue, isEmpty);

        secondGate.complete();
        await Future<void>.microtask(() {});

        expect(bloc.postAwaitCanceledSnapshots[2], isFalse);
        expect(bloc.stateValue, equals([2]));
        expect(observer.errors, isEmpty);
      },
    );

    test(
      'onCancel callbacks run synchronously in LIFO order inside superseded '
      'handler Zone',
      () async {
        final bloc = _RestartableCancelBloc();
        addTearDown(bloc.close);

        final firstGate = Completer<void>();
        final secondGate = Completer<void>();
        final log = <String>[];
        Object? firstDispatchToken;
        Object? callback1DispatchToken;
        Object? callback2DispatchToken;
        Object? callback1CustomValue;
        final customKey = Object();

        bloc.onCustomCancel = (id) {
          if (id == 1) {
            firstDispatchToken =
                Zone.current[BlocSignalBase.ambientZoneDispatchTokenKey];
            onCancel(() {
              callback1DispatchToken =
                  Zone.current[BlocSignalBase.ambientZoneDispatchTokenKey];
              callback1CustomValue = Zone.current[customKey];
              log.add('first-1');
            });
            onCancel(() => log.add('first-2'));
          }
        };

        runZoned(
          () => bloc.add(_WorkEvent(1, completer: firstGate)),
          zoneValues: {customKey: 'zone-1'},
        );
        await Future<void>.microtask(() {});
        expect(log, isEmpty);

        runZoned(
          () => bloc.add(_WorkEvent(2, completer: secondGate)),
          zoneValues: {customKey: 'zone-2'},
        );

        // Synchronous execution on supersede before even awaiting microtask.
        expect(log, equals(['first-2', 'first-1']));
        expect(firstDispatchToken, isNotNull);
        expect(callback1DispatchToken, same(firstDispatchToken));
        expect(callback1CustomValue, equals('zone-1'));
        expect(callback2DispatchToken, isNull);

        firstGate.complete();
        secondGate.complete();
        await Future<void>.microtask(() {});
      },
    );

    test(
      'calling onCancel when already canceled invokes callback immediately '
      'and synchronously',
      () async {
        final bloc = _RestartableCancelBloc();
        addTearDown(bloc.close);

        final firstGate = Completer<void>();
        final secondGate = Completer<void>();
        var lateCallbackRan = false;

        bloc.add(_WorkEvent(1, completer: firstGate));
        await Future<void>.microtask(() {});

        bloc.add(_WorkEvent(2, completer: secondGate));
        firstGate.complete();
        await Future<void>.microtask(() {});

        expect(bloc.tokens[1]?.isCanceled, isTrue);
        bloc.tokens[1]!.onCancel(() {
          lateCallbackRan = true;
        });
        expect(lateCallbackRan, isTrue);

        secondGate.complete();
        await Future<void>.microtask(() {});
      },
    );

    test(
      'close() cancels active handler, runs onCancel in LIFO order, and '
      'suppresses late emit',
      () async {
        final bloc = _RestartableCancelBloc();
        final gate = Completer<void>();
        final log = <String>[];

        bloc.onCustomCancel = (id) {
          onCancel(() => log.add('c1'));
          onCancel(() => log.add('c2'));
        };

        bloc.add(_WorkEvent(1, completer: gate));
        await Future<void>.microtask(() {});
        expect(log, isEmpty);

        await bloc.close();
        expect(log, equals(['c2', 'c1']));
        expect(bloc.tokens[1]?.isCanceled, isTrue);

        gate.complete();
        await Future<void>.microtask(() {});
        expect(bloc.stateValue, isEmpty);
        expect(observer.errors, isEmpty);
      },
    );

    test(
      'isolates exceptions thrown by onCancel via host.onError so remaining '
      'callbacks and close() complete',
      () async {
        final bloc = _RestartableCancelBloc();
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final log = <String>[];
        final boom = Exception('cleanup failed');

        bloc.onCustomCancel = (id) {
          onCancel(() => log.add('$id-first'));
          onCancel(() {
            log.add('$id-throwing');
            throw boom;
          });
          onCancel(() => log.add('$id-last'));
        };

        bloc.add(_WorkEvent(1, completer: gate1));
        await Future<void>.microtask(() {});

        // Supersede triggers LIFO: last -> throwing -> first
        bloc.add(_WorkEvent(2, completer: gate2));
        expect(log, equals(['1-last', '1-throwing', '1-first']));
        expect(observer.errors, contains(boom));

        log.clear();
        observer.errors.clear();
        await bloc.close();
        expect(log, equals(['2-last', '2-throwing', '2-first']));
        expect(observer.errors, contains(boom));

        gate1.complete();
        gate2.complete();
        await Future<void>.microtask(() {});
      },
    );

    test(
      'synchronous fast-path has isCanceled false and avoids extra runZoned '
      'overhead',
      () async {
        var zoneRunCount = 0;
        final countingZone = Zone.current.fork(
          specification: ZoneSpecification(
            run: <R>(self, parent, zone, f) {
              zoneRunCount++;
              return parent.run(zone, f);
            },
          ),
        );

        late _RestartableSyncBloc bloc;
        countingZone.run(() {
          bloc = _RestartableSyncBloc();
        });
        addTearDown(bloc.close);

        zoneRunCount = 0;
        countingZone.run(() {
          bloc.add(_WorkEvent(1));
        });

        expect(bloc.stateValue, equals([1]));
        expect(bloc.sawCanceled, isFalse);
        expect(bloc.hadToken, isTrue);
        // Outer countingZone.run (1) + BlocSignalMixin.add()'s single
        // runZoned (2), proving restartable() adds zero extra runZoned
        // allocations.
        expect(zoneRunCount, equals(2));
      },
    );

    test(
      'direct invocation isolates onCancel exceptions via Zone when no host '
      'is bound',
      () async {
        final transformer = restartable<_WorkEvent, List<int>>();
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final log = <String>[];
        final uncaught = <Object>[];
        final boom = Exception('standalone cleanup error');

        await runZonedGuarded(
          () async {
            final f1 = transformer(
              _WorkEvent(1, completer: gate1),
              (event, emit) async {
                onCancel(() => log.add('first'));
                onCancel(() {
                  log.add('throwing');
                  throw boom;
                });
                onCancel(() => log.add('last'));
                await event.completer!.future;
              },
              (_) {},
            );

            final f2 = transformer(
              _WorkEvent(2, completer: gate2),
              (event, emit) async {
                await event.completer!.future;
              },
              (_) {},
            );

            gate1.complete();
            gate2.complete();
            await Future.wait([
              if (f1 is Future<void>) f1,
              if (f2 is Future<void>) f2,
            ]);
          },
          (error, _) => uncaught.add(error),
        );

        expect(log, equals(['last', 'throwing', 'first']));
        expect(uncaught, contains(boom));
      },
    );

    test(
      'direct invocation of restartable() outside BlocSignalMixin.add() binds '
      'CancellationToken via runZoned fallback',
      () async {
        final transformer = restartable<_WorkEvent, List<int>>();
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        CancellationToken? token1;
        var canceled1 = false;
        final emissions = <List<int>>[];

        final f1 = transformer(
          _WorkEvent(1, completer: gate1),
          (event, emit) async {
            token1 = CancellationToken.current;
            onCancel(() => canceled1 = true);
            await event.completer!.future;
            emit([event.id]);
          },
          emissions.add,
        );
        expect(token1, isNotNull);
        expect(token1!.isCanceled, isFalse);

        final f2 = transformer(
          _WorkEvent(2, completer: gate2),
          (event, emit) async {
            await event.completer!.future;
            emit([event.id]);
          },
          emissions.add,
        );

        expect(token1!.isCanceled, isTrue);
        expect(canceled1, isTrue);

        gate1.complete();
        gate2.complete();
        await Future.wait([
          if (f1 is Future<void>) f1,
          if (f2 is Future<void>) f2,
        ]);

        expect(
          emissions,
          equals([
            [2],
          ]),
        );
      },
    );

    test('skips handler execution when host is already closed on entry',
        () async {
      final bloc = _RestartableCancelBloc();
      await bloc.close();

      var invoked = false;
      final transformer = restartable<_WorkEvent, List<int>>(bloc: bloc);
      final result = transformer(
        _WorkEvent(1),
        (event, emit) => invoked = true,
        (_) {},
      );
      expect(result, isNull);
      expect(invoked, isFalse);
    });

    test(
      '(Issue #498: BLOCKER-1) reentrant bloc.close() from '
      'onTelemetry(taskPreempted) aborts superseding handler',
      () async {
        final closeObserver = _ReentrantCloseOnTelemetryObserver(
          targetName: BlocTelemetryKeys.taskPreempted,
        );
        BlocSignalObserver.observer = closeObserver;

        final bloc = _RestartableCancelBloc();
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        var cancel1Ran = false;

        bloc.onCustomCancel = (id) {
          if (id == 1) {
            onCancel(() => cancel1Ran = true);
          }
        };

        bloc.add(_WorkEvent(1, completer: gate1));
        await Future<void>.microtask(() {});

        // Supersede triggers onTelemetry(taskPreempted) -> bloc.close()
        bloc.add(_WorkEvent(2, completer: gate2));

        expect(bloc.isClosed, isTrue);
        expect(cancel1Ran, isTrue);
        expect(bloc.tokens.containsKey(2), isFalse);
        expect(closeObserver.errors, isEmpty);

        gate1.complete();
        gate2.complete();
        await Future<void>.microtask(() {});
      },
    );

    test(
      '(Issue #498: BLOCKER-1) reentrant bloc.close() from onCancel() '
      'aborts superseding handler',
      () async {
        final bloc = _RestartableCancelBloc();
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();

        bloc.onCustomCancel = (id) {
          if (id == 1) {
            onCancel(() {
              unawaited(bloc.close());
            });
          }
        };

        bloc.add(_WorkEvent(1, completer: gate1));
        await Future<void>.microtask(() {});

        bloc.add(_WorkEvent(2, completer: gate2));

        expect(bloc.isClosed, isTrue);
        expect(bloc.tokens.containsKey(2), isFalse);

        gate1.complete();
        gate2.complete();
        await Future<void>.microtask(() {});
      },
    );

    test(
      '(Issue #498: BLOCKER-2) reentrant bloc.add() from onCancel() '
      'preempts cleanly without losing or double-running events',
      () async {
        final bloc = _RestartableCancelBloc();
        addTearDown(bloc.close);

        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final gate3 = Completer<void>();
        var reentered = false;

        bloc.onCustomCancel = (id) {
          if (id == 1 && !reentered) {
            reentered = true;
            bloc.add(_WorkEvent(3, completer: gate3));
          }
        };

        bloc.add(_WorkEvent(1, completer: gate1));
        await Future<void>.microtask(() {});

        // Event 2 preempts 1 -> onCancel adds 3 -> loop preempts 3 -> 2 wins
        bloc.add(_WorkEvent(2, completer: gate2));
        await Future<void>.microtask(() {});

        expect(bloc.tokens[1]?.isCanceled, isTrue);
        expect(bloc.tokens[3]?.isCanceled, isTrue);
        expect(bloc.tokens[2]?.isCanceled, isFalse);

        gate1.complete();
        gate3.complete();
        gate2.complete();
        await Future<void>.microtask(() {});

        expect(bloc.stateValue, equals([2]));
      },
    );

    test(
      '(Issue #498: BLOCKER-2) reentrant bloc.add() from '
      'onTelemetry(taskPreempted) preempts cleanly',
      () async {
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final gate3 = Completer<void>();
        final addObserver = _ReentrantAddOnTelemetryObserver(
          () => _WorkEvent(3, completer: gate3),
          targetName: BlocTelemetryKeys.taskPreempted,
        );
        BlocSignalObserver.observer = addObserver;

        final bloc = _RestartableCancelBloc();
        addTearDown(bloc.close);

        bloc.add(_WorkEvent(1, completer: gate1));
        await Future<void>.microtask(() {});

        bloc.add(_WorkEvent(2, completer: gate2));
        await Future<void>.microtask(() {});

        expect(bloc.tokens[1]?.isCanceled, isTrue);
        expect(bloc.tokens[3]?.isCanceled, isTrue);
        expect(bloc.tokens[2]?.isCanceled, isFalse);

        gate1.complete();
        gate3.complete();
        gate2.complete();
        await Future<void>.microtask(() {});

        expect(bloc.stateValue, equals([2]));
        expect(addObserver.errors, isEmpty);
      },
    );

    test(
      '(Issue #498: BLOCKER-3) polymorphic multi-handler bloc isolates '
      'CancellationToken per handler',
      () async {
        final bloc = _PolymorphicRestartableBloc();
        addTearDown(bloc.close);

        final baseGate = Completer<void>();
        final subGate1 = Completer<void>();

        bloc.add(_SubWorkEvent(1, baseGate: baseGate, subGate: subGate1));
        await Future<void>.microtask(() {});

        expect(bloc.baseTokens[1], isNotNull);
        expect(bloc.subTokens[1], isNotNull);
        expect(identical(bloc.baseTokens[1], bloc.subTokens[1]), isFalse);
        expect(bloc.baseTokens[1]!.isCanceled, isFalse);
        expect(bloc.subTokens[1]!.isCanceled, isFalse);

        // Dispatch a base-only event: only on<_TestEvent> is superseded;
        // on<_SubWorkEvent> (subTokens[1]) must NOT be canceled!
        final baseGate2 = Completer<void>();
        bloc.add(_BaseOnlyEvent(2, baseGate: baseGate2));
        await Future<void>.microtask(() {});

        expect(bloc.baseTokens[1]!.isCanceled, isTrue);
        expect(bloc.subTokens[1]!.isCanceled, isFalse);

        subGate1.complete();
        baseGate.complete();
        baseGate2.complete();
        await Future<void>.microtask(() {});

        expect(bloc.stateValue, containsAll(['sub:1', 'base:2']));
        expect(bloc.stateValue, isNot(contains('base:1')));
      },
    );

    test(
      '(Issue #498: BLOCKER-4) synchronous throwing handler clears active '
      'execution and cancellation tokens so follow-up add and close are clean',
      () async {
        final bloc = _RestartableSyncErrorBloc();
        var cancelRan = false;
        bloc.onSyncCancel = () => cancelRan = true;

        final boom = Exception('sync boom');
        bloc.add(_WorkEvent(1, syncError: true, error: boom));

        expect(observer.errors, contains(boom));
        expect(cancelRan, isFalse);
        expect(
          observer.telemetry
              .where((t) => t.name == BlocTelemetryKeys.taskPreempted),
          isEmpty,
        );

        // Follow-up add must NOT emit taskPreempted or cancel errored handler.
        bloc.add(_WorkEvent(2));
        expect(
          observer.telemetry
              .where((t) => t.name == BlocTelemetryKeys.taskPreempted),
          isEmpty,
        );
        expect(bloc.stateValue, equals([2]));

        await bloc.close();
        expect(cancelRan, isFalse);
      },
    );

    test(
      '(Issue #498: BLOCKER-5) active and superseded async handler rejections '
      'maintain accurate activeCancellationToken state',
      () async {
        final bloc = _RestartableCancelBloc();
        final gate1 = Completer<void>();
        final gate2 = Completer<void>();
        final gate3 = Completer<void>();
        final cancelLog = <int>[];

        bloc.onCustomCancel = (id) {
          onCancel(() => cancelLog.add(id));
        };

        // 1. Active rejection clears tokens cleanly
        final err1 = Exception('async err 1');
        bloc.add(_WorkEvent(1, completer: gate1, error: err1));
        await Future<void>.microtask(() {});
        gate1.complete();
        await Future<void>.microtask(() {});

        expect(observer.errors, contains(err1));
        expect(cancelLog, isEmpty);

        // Next event should NOT emit taskPreempted or cancel event 1
        bloc.add(
          _WorkEvent(2, completer: gate2, error: Exception('async err 2')),
        );
        await Future<void>.microtask(() {});
        expect(
          observer.telemetry
              .where((t) => t.name == BlocTelemetryKeys.taskPreempted),
          isEmpty,
        );

        // 2. Superseded rejection does NOT clear newer activeCancellationToken
        bloc.add(_WorkEvent(3, completer: gate3));
        await Future<void>.microtask(() {});
        expect(cancelLog, equals([2]));

        // Now reject superseded event 2; event 3's token must remain active
        gate2.complete();
        await Future<void>.microtask(() {});
        expect(bloc.tokens[3]?.isCanceled, isFalse);

        // Closing bloc must still cancel event 3
        await bloc.close();
        expect(cancelLog, equals([2, 3]));
        expect(bloc.tokens[3]?.isCanceled, isTrue);

        gate3.complete();
        await Future<void>.microtask(() {});
      },
    );

    test(
      '(Issue #498: BLOCKER-6) token.cancel() is idempotent and runs LIFO '
      'callbacks at most once',
      () {
        var calls = 0;
        final order = <int>[];
        final token = CancellationToken(zone: Zone.current);
        token.onCancel(() {
          calls++;
          order.add(1);
        });
        token.onCancel(() {
          calls++;
          order.add(2);
        });

        token.cancel();
        token.cancel();
        token.cancel();

        expect(token.isCanceled, isTrue);
        expect(calls, equals(2));
        expect(order, equals([2, 1]));
      },
    );

    test(
      '(Issue #498: BLOCKER-7) custom BlocSignalBase with no-op '
      'registerCloseCallback suppresses late emit when host.isClosed becomes '
      'true mid-flight',
      () async {
        final host = _MinimalNoOpBloc();
        final gate = Completer<void>();
        final emissions = <int>[];
        final transformer = restartable<_WorkEvent, int>(bloc: host);

        final future = transformer(
          _WorkEvent(1, completer: gate),
          (event, emit) async {
            await event.completer!.future;
            emit(42);
          },
          emissions.add,
        );

        host.isClosed = true;
        gate.complete();
        if (future is Future<void>) {
          await future;
        }

        expect(emissions, isEmpty);
      },
    );

    test(
      '(Issue #498: Round 2 BLOCKER-1) nested restartable() inside active '
      'restartable() handler isolates tokens and Zones',
      () async {
        final innerTransformer = restartable<_WorkEvent, List<int>>();
        final bloc = _NestedRestartableBloc(innerTransformer);
        addTearDown(bloc.close);

        final outerGate1 = Completer<void>();
        final outerGate2 = Completer<void>();
        final innerGate1 = Completer<void>();
        final innerGate2 = Completer<void>();
        final cancelTokens = <String, CancellationToken?>{};

        bloc.onOuterCancel = () {
          cancelTokens['outer'] = CancellationToken.current;
        };
        bloc.onInnerCancel = (id) {
          cancelTokens['inner-$id'] = CancellationToken.current;
        };

        bloc.add(
          _NestedWorkEvent(
            1,
            outerGate: outerGate1,
            innerGate: innerGate1,
          ),
        );
        await Future<void>.microtask(() {});

        final outerToken1 = bloc.outerTokens[1];
        final innerToken1 = bloc.innerTokens[1];
        expect(outerToken1, isNotNull);
        expect(innerToken1, isNotNull);
        expect(identical(outerToken1, innerToken1), isFalse);

        // Supersede only the inner transformer directly: innerToken1 cancels in
        // its own Zone, while outerToken1 remains active.
        final innerFuture2 = innerTransformer(
          _WorkEvent(2, completer: innerGate2),
          (event, emit) async {
            bloc.innerTokens[2] = CancellationToken.current!;
            await event.completer!.future;
          },
          (_) {},
        );

        expect(innerToken1!.isCanceled, isTrue);
        expect(outerToken1!.isCanceled, isFalse);
        expect(identical(cancelTokens['inner-1'], innerToken1), isTrue);

        // Now supersede the outer bloc handler: outerToken1 cancels in its
        // own Zone, while innerToken2 remains active.
        bloc.add(
          _NestedWorkEvent(
            3,
            outerGate: outerGate2,
            innerGate: Completer<void>()..complete(),
            callInner: false,
          ),
        );
        await Future<void>.microtask(() {});

        expect(outerToken1.isCanceled, isTrue);
        expect(identical(cancelTokens['outer'], outerToken1), isTrue);
        expect(bloc.innerTokens[2]!.isCanceled, isFalse);

        innerGate1.complete();
        innerGate2.complete();
        outerGate1.complete();
        outerGate2.complete();
        if (innerFuture2 is Future<void>) {
          await innerFuture2;
        }
        await Future<void>.microtask(() {});
      },
    );

    test(
      '(Issue #498: Round 2 BLOCKER-2) synchronous multi-handler dispatch '
      'isolates restartable() token from non-restartable() sibling',
      () async {
        final bloc = _SyncPolymorphicBloc();
        addTearDown(bloc.close);

        bloc.add(_SyncSubEvent(1));

        expect(bloc.baseSawToken, isNull);
        expect(bloc.baseSawCanceled, isFalse);
        expect(bloc.subSawToken, isNotNull);
        expect(bloc.subSawCanceled, isFalse);
        expect(bloc.stateValue, equals(['base:1', 'sub:1']));
      },
    );

    test(
      '(Issue #498: Round 3 BLOCKER-1) stale emit() invoked synchronously '
      'inside onCancel() upon preemption is silently suppressed',
      () async {
        final bloc = _RestartableEmitOnCancelBloc();
        addTearDown(bloc.close);

        final gate1 = Completer<void>();
        final gate2 = Completer<void>();

        bloc.add(_WorkEvent(1, completer: gate1));
        await Future<void>.microtask(() {});

        // Preempt event 1: its onCancel callback synchronously calls
        // emit([999]) between prevToken.cancel() and ++executionToken.
        bloc.add(_WorkEvent(2, completer: gate2));

        expect(bloc.cancelEmitAttempted, isTrue);
        expect(bloc.stateValue, isEmpty);
        expect(observer.transitions, isEmpty);

        gate1.complete();
        gate2.complete();
        await Future<void>.microtask(() {});

        expect(bloc.stateValue, equals([2]));
        expect(observer.transitions, hasLength(1));
        expect(observer.transitions.single.state, equals([2]));
      },
    );
  });
}

class _RestartableEmitOnCancelBloc extends BlocSignal<_TestEvent, List<int>> {
  _RestartableEmitOnCancelBloc() : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) async {
        onCancel(() {
          if (event.id == 1) {
            cancelEmitAttempted = true;
            emit([999]);
          }
        });
        if (event.completer != null) {
          await event.completer!.future;
        }
        emit([...stateValue, event.id]);
      },
      transformer: restartable(),
    );
  }

  bool cancelEmitAttempted = false;
}

final class _NestedWorkEvent extends _TestEvent {
  _NestedWorkEvent(
    this.id, {
    required this.outerGate,
    required this.innerGate,
    this.callInner = true,
  });

  final int id;
  final Completer<void> outerGate;
  final Completer<void> innerGate;
  final bool callInner;
}

class _NestedRestartableBloc extends BlocSignal<_TestEvent, List<int>> {
  _NestedRestartableBloc(this.innerTransformer)
      : super(initialState: const []) {
    on<_NestedWorkEvent>(
      (event, emit) async {
        outerTokens[event.id] = CancellationToken.current!;
        onCancel(() => onOuterCancel?.call());

        if (event.callInner) {
          final innerFuture = innerTransformer(
            _WorkEvent(event.id, completer: event.innerGate),
            (innerEvent, innerEmit) async {
              innerTokens[innerEvent.id] = CancellationToken.current!;
              onCancel(() => onInnerCancel?.call(innerEvent.id));
              await innerEvent.completer!.future;
            },
            (_) {},
          );
          if (innerFuture is Future<void>) {
            await innerFuture;
          }
        }
        await event.outerGate.future;
        emit([...stateValue, event.id]);
      },
      transformer: restartable(),
    );
  }

  final EventTransformer<_WorkEvent, List<int>> innerTransformer;
  final Map<int, CancellationToken> outerTokens = {};
  final Map<int, CancellationToken> innerTokens = {};
  void Function()? onOuterCancel;
  void Function(int id)? onInnerCancel;
}

final class _SyncSubEvent extends _TestEvent {
  _SyncSubEvent(this.id);

  final int id;
}

class _SyncPolymorphicBloc extends BlocSignal<_TestEvent, List<String>> {
  _SyncPolymorphicBloc() : super(initialState: const []) {
    on<_TestEvent>((event, emit) {
      if (event is _SyncSubEvent) {
        baseSawToken = CancellationToken.current;
        baseSawCanceled = isCanceled;
        emit([...stateValue, 'base:${event.id}']);
      }
    });
    on<_SyncSubEvent>(
      (event, emit) {
        subSawToken = CancellationToken.current;
        subSawCanceled = isCanceled;
        emit([...stateValue, 'sub:${event.id}']);
      },
      transformer: restartable(),
    );
  }

  CancellationToken? baseSawToken;
  bool baseSawCanceled = true;
  CancellationToken? subSawToken;
  bool subSawCanceled = true;
}

final class _BaseOnlyEvent extends _TestEvent {
  _BaseOnlyEvent(this.id, {required this.baseGate});

  final int id;
  final Completer<void> baseGate;
}

final class _SubWorkEvent extends _TestEvent {
  _SubWorkEvent(
    this.id, {
    required this.baseGate,
    required this.subGate,
  });

  final int id;
  final Completer<void> baseGate;
  final Completer<void> subGate;
}

class _PolymorphicRestartableBloc extends BlocSignal<_TestEvent, List<String>> {
  _PolymorphicRestartableBloc() : super(initialState: const []) {
    on<_TestEvent>(
      (event, emit) async {
        final (id, gate) = switch (event) {
          _BaseOnlyEvent(:final id, :final baseGate) => (id, baseGate),
          _SubWorkEvent(:final id, :final baseGate) => (id, baseGate),
          _ => throw StateError('Unexpected event $event'),
        };
        final token = CancellationToken.current;
        if (token != null) {
          baseTokens[id] = token;
        }
        await gate.future;
        emit([...stateValue, 'base:$id']);
      },
      transformer: restartable(),
    );
    on<_SubWorkEvent>(
      (event, emit) async {
        final token = CancellationToken.current;
        if (token != null) {
          subTokens[event.id] = token;
        }
        await event.subGate.future;
        emit([...stateValue, 'sub:${event.id}']);
      },
      transformer: restartable(),
    );
  }

  final Map<int, CancellationToken> baseTokens = {};
  final Map<int, CancellationToken> subTokens = {};
}

class _RestartableSyncErrorBloc extends BlocSignal<_TestEvent, List<int>> {
  _RestartableSyncErrorBloc() : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) {
        if (event.syncError) {
          onCancel(() => onSyncCancel?.call());
          throw event.error ?? Exception('sync error');
        }
        emit([...stateValue, event.id]);
      },
      transformer: restartable(),
    );
  }

  void Function()? onSyncCancel;
}

class _RestartableCancelBloc extends BlocSignal<_TestEvent, List<int>> {
  _RestartableCancelBloc() : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) async {
        final token = CancellationToken.current;
        if (token != null) {
          tokens[event.id] = token;
        }
        canceledSnapshots[event.id] = isCanceled;
        onCustomCancel?.call(event.id);
        if (event.completer != null) {
          await event.completer!.future;
        }
        if (event.error != null) {
          throw event.error!;
        }
        postAwaitCanceledSnapshots[event.id] = isCanceled;
        emit([...stateValue, event.id]);
      },
      transformer: restartable(),
    );
  }

  final Map<int, CancellationToken> tokens = {};
  final Map<int, bool> canceledSnapshots = {};
  final Map<int, bool> postAwaitCanceledSnapshots = {};
  void Function(int id)? onCustomCancel;
}

class _RestartableSyncBloc extends BlocSignal<_TestEvent, List<int>> {
  _RestartableSyncBloc() : super(initialState: const []) {
    on<_WorkEvent>(
      (event, emit) {
        hadToken = CancellationToken.current != null;
        sawCanceled = isCanceled;
        emit([...stateValue, event.id]);
      },
      transformer: restartable(),
    );
  }

  bool hadToken = false;
  bool sawCanceled = true;
}

class _ReentrantCloseOnTelemetryObserver extends BlocSignalObserver {
  _ReentrantCloseOnTelemetryObserver({
    this.targetName = BlocTelemetryKeys.eventDropped,
  });

  final String targetName;
  final List<Object> errors = [];
  var _triggered = false;

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    if (!_triggered && name == targetName) {
      _triggered = true;
      unawaited(bloc.close());
    }
    _triggered = false;
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }
}

class _ReentrantAddOnTelemetryObserver extends BlocSignalObserver {
  _ReentrantAddOnTelemetryObserver(
    this.eventFactory, {
    this.targetName = BlocTelemetryKeys.eventDropped,
  });

  final _TestEvent Function() eventFactory;
  final String targetName;
  final List<Object> errors = [];
  var _triggered = false;

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    if (!_triggered &&
        name == targetName &&
        bloc is BlocSignal<_TestEvent, List<int>>) {
      _triggered = true;
      bloc.add(eventFactory());
    }
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }
}

class _MinimalNoOpBloc extends BlocSignalBase<int> {
  @override
  bool isClosed = false;

  @override
  ReadonlySignal<int> get state => throw UnimplementedError();

  @override
  int get value => 0;

  @override
  int get stateValue => 0;

  @override
  bool equals(int previous, int current) => previous == current;

  @override
  Object get zoneEventKey => throw UnimplementedError();

  @override
  Object get zoneBlocKey => throw UnimplementedError();

  @override
  void emit(int newState) {}

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
  Future<void> close() async {}

  @override
  bool get isHistorySuppressed => false;

  @override
  void runWithoutHistory(void Function() action) => action();
}
