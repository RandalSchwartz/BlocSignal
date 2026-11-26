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
}

class _ReentrantCloseOnTelemetryObserver extends BlocSignalObserver {
  final List<Object> errors = [];
  var _triggered = false;

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    if (!_triggered && name == BlocTelemetryKeys.eventDropped) {
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
  _ReentrantAddOnTelemetryObserver(this.eventFactory);

  final _TestEvent Function() eventFactory;
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
        name == BlocTelemetryKeys.eventDropped &&
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
