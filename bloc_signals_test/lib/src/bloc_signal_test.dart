import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:fake_async/fake_async.dart';
import 'package:meta/meta.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart' as test_pkg;

final Object _fakeAsyncZoneKey = Object();

FakeAsync _requireFakeAsync(String caller) {
  final fakeAsync = Zone.current[_fakeAsyncZoneKey];
  if (fakeAsync is! FakeAsync) {
    throw StateError(
      '$caller() can only be called inside '
      'blocSignalTest(..., fakeAsync: true).',
    );
  }
  return fakeAsync;
}

/// Advances the virtual clock inside a `blocSignalTest(..., fakeAsync: true)`
/// block by [duration], firing scheduled timers and flushing microtasks.
///
/// Throws a [StateError] if called outside an active
/// `blocSignalTest(..., fakeAsync: true)` execution zone.
///
/// ```dart
/// blocSignalTest<DebounceCubit, int>(
///   'debounces rapid updates in virtual time',
///   build: DebounceCubit.new,
///   act: (cubit) {
///     cubit.scheduleIncrement(1, const Duration(seconds: 5));
///     elapse(const Duration(seconds: 5));
///   },
///   fakeAsync: true,
///   expect: () => [1],
/// );
/// ```
void elapse(Duration duration) => _requireFakeAsync('elapse').elapse(duration);

/// Flushes pending microtasks inside a `blocSignalTest(..., fakeAsync: true)`
/// block without advancing the virtual clock.
///
/// Throws a [StateError] if called outside an active
/// `blocSignalTest(..., fakeAsync: true)` execution zone.
///
/// ```dart
/// blocSignalTest<CounterCubit, int>(
///   'flushes scheduled microtasks deterministically',
///   build: CounterCubit.new,
///   act: (cubit) {
///     scheduleMicrotask(cubit.increment);
///     flushMicrotasks();
///   },
///   fakeAsync: true,
///   expect: () => [1],
/// );
/// ```
void flushMicrotasks() =>
    _requireFakeAsync('flushMicrotasks').flushMicrotasks();

/// Declaratively tests a [BlocSignalBase] instance.
///
/// [blocSignalTest] creates a new test case with the given [description].
///
/// [build] should construct and return the state container instance under
/// test. State seeding can be performed directly inside [build]:
/// ```dart
/// build: () => CounterBloc(initialState: 5),
/// ```
///
/// ### Widget & Golden Testing (`BlocSignalProvider.value`)
/// When injecting a test double into widget or golden tests via
/// `BlocSignalProvider.value`, note that `bloc.state` is a reactive
/// `ReadonlySignal<State>` whereas `bloc.value` (and `bloc.stateValue`) returns
/// the raw `State` snapshot. Prefer a lightweight Fake extending
/// [CubitSignal] or [BlocSignal] with `void emitState(State s) => emit(s);`,
/// or back a `mocktail` `Mock` with a `signal<State>(initial)` returned from
/// `when(() => mock.state).thenReturn(stateSignal)` alongside
/// `registerFallbackValue` for `mock.equals(any(), any())`, stubs for
/// `mock.value`, `mock.stateValue`, `mock.isClosed`, and
/// `when(() => mock.close()).thenAnswer((_) async => stateSignal.dispose())`
/// registered with `addTearDown(mock.close)`.
///
/// [setUp] is an optional callback invoked prior to building the state
/// container.
///
/// [seed] is an optional callback returning an initial state to emit onto the
/// built container before state-change recording begins, without recording the
/// seeded state as an emitted transition.
///
/// [act] is an optional callback invoked after construction to trigger
/// events or methods.
///
/// [skip] is an optional `int` that defaults to 0 and defines how many
/// emitted states should be skipped from the expectation list.
///
/// [wait] is an optional [Duration] to await after [act] before checking
/// expectations. When [fakeAsync] is `true`, [wait] advances the virtual clock
/// via `FakeAsync.elapse` instead of waiting in wall-clock time.
///
/// [fakeAsync] is an optional `bool` that defaults to `false`. When `true`,
/// [build], [act], and [wait] execute inside a `FakeAsync` virtual-time zone,
/// enabling deterministic, zero-wall-clock-latency testing of timers and delays
/// via [wait], [elapse], and [flushMicrotasks].
///
/// ```dart
/// blocSignalTest<TimerCubit, int>(
///   'emits after virtual delay without waiting in real time',
///   build: TimerCubit.new,
///   act: (cubit) => cubit.incrementAfter(const Duration(seconds: 30)),
///   fakeAsync: true,
///   wait: const Duration(seconds: 30),
///   expect: () => [1],
/// );
/// ```
///
/// [expect] is an optional callback returning an [Iterable] or
/// [test_pkg.Matcher] of expected states.
///
/// [verify] is an optional callback invoked after expectations are verified.
///
/// [errors] is an optional callback returning an [Iterable] or
/// [test_pkg.Matcher] of expected errors. When provided, captures errors
/// reported to `onError` as well as rethrown [Error] subtypes (such as
/// [StateError] or [ArgumentError]) and direct synchronous or asynchronous
/// throws during [act] and [wait]. When omitted, unhandled errors are rethrown
/// to fail the test immediately.
///
/// [expectTelemetry] is an optional callback returning an [Iterable] or
/// [test_pkg.Matcher] of expected telemetry records (such as [isTelemetry]).
///
/// [expectComputed] is an optional callback receiving the built container and
/// returning a map of [ReadonlySignal] instances to expected literal values or
/// [test_pkg.Matcher]s, asserted after [expect], [errors], and
/// [expectTelemetry].
///
/// [tearDown] is an optional callback invoked after test completion.
@isTest
void blocSignalTest<B extends BlocSignalBase<State>, State>(
  String description, {
  required B Function() build,
  FutureOr<void> Function()? setUp,
  State Function()? seed,
  FutureOr<void> Function(B bloc)? act,
  Duration? wait,
  bool fakeAsync = false,
  int skip = 0,
  Object? Function()? expect,
  FutureOr<void> Function(B bloc)? verify,
  Object? Function()? errors,
  Object? Function()? expectTelemetry,
  Map<ReadonlySignal<Object?>, Object?> Function(B bloc)? expectComputed,
  FutureOr<void> Function()? tearDown,
  dynamic tags,
}) {
  test_pkg.test(
    description,
    () => runBlocSignalTest<B, State>(
      build: build,
      setUp: setUp,
      seed: seed,
      act: act,
      wait: wait,
      fakeAsync: fakeAsync,
      skip: skip,
      expect: expect,
      verify: verify,
      errors: errors,
      expectTelemetry: expectTelemetry,
      expectComputed: expectComputed,
      tearDown: tearDown,
    ),
    tags: tags,
  );
}

/// Internal runner for [blocSignalTest], exposed for testing error propagation
/// and lifecycle teardown guarantees.
///
/// ```dart
/// await runBlocSignalTest<CounterCubit, int>(
///   build: CounterCubit.new,
///   act: (cubit) => cubit.increment(),
///   expect: () => [1],
/// );
/// ```
@visibleForTesting
Future<void> runBlocSignalTest<B extends BlocSignalBase<State>, State>({
  required B Function() build,
  FutureOr<void> Function()? setUp,
  State Function()? seed,
  FutureOr<void> Function(B bloc)? act,
  Duration? wait,
  bool fakeAsync = false,
  int skip = 0,
  Object? Function()? expect,
  FutureOr<void> Function(B bloc)? verify,
  Object? Function()? errors,
  Object? Function()? expectTelemetry,
  Map<ReadonlySignal<Object?>, Object?> Function(B bloc)? expectComputed,
  FutureOr<void> Function()? tearDown,
}) async {
  final baselineObserver = BlocSignalObserver.observer;
  final states = <State>[];
  final caughtErrors = <Object>[];
  final caughtTelemetry = <BlocTelemetryEntry>[];
  B? bloc;
  void Function()? disposeListener;

  try {
    await setUp?.call();
    final activeObserver = BlocSignalObserver.observer;

    final initialErrors = <(Object, Object)>[];
    final initialTelemetry = <(Object, BlocTelemetryEntry)>[];

    final testObserver = _TestBlocSignalObserver(
      parent: activeObserver,
      onErrorCallback: (b, error, stackTrace) {
        if (bloc == null) {
          initialErrors.add((b, error));
        } else if (identical(b, bloc)) {
          caughtErrors.add(error);
        }
      },
      onTelemetryCallback: (b, name, {event, metadata}) {
        final entry = BlocTelemetryEntry(
          name: name,
          event: event,
          metadata: metadata,
        );
        if (bloc == null) {
          initialTelemetry.add((b, entry));
        } else if (identical(b, bloc)) {
          caughtTelemetry.add(entry);
        }
      },
    );
    BlocSignalObserver.observer = testObserver;

    B prepareBloc() {
      final built = build();
      bloc = built;
      for (final pair in initialErrors) {
        if (identical(pair.$1, built)) {
          caughtErrors.add(pair.$2);
        }
      }
      for (final pair in initialTelemetry) {
        if (identical(pair.$1, built)) {
          caughtTelemetry.add(pair.$2);
        }
      }

      if (seed != null) {
        // Intentional `invalid_use_of_protected_member` and
        // `invalid_use_of_visible_for_testing_member`: apply seeded state
        // before subscribing so it is not recorded as an emission.
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        built.emit(seed());
      }

      var initialSkipped = false;
      disposeListener = built.state.subscribe((value) {
        if (!initialSkipped) {
          initialSkipped = true;
          return;
        }
        states.add(value);
      });
      return built;
    }

    final unhandledErrors = <(Object, StackTrace)>[];
    final parentZone = Zone.current;
    final completer = Completer<void>();
    void recordError(Object error, StackTrace stackTrace) {
      if (completer.isCompleted) {
        parentZone.handleUncaughtError(error, stackTrace);
        return;
      }
      if (errors == null) {
        unhandledErrors.add((error, stackTrace));
      } else if (!caughtErrors.any((existing) => identical(existing, error))) {
        caughtErrors.add(error);
      }
    }

    if (fakeAsync) {
      try {
        FakeAsync().run((async) {
          final targetBloc = runZoned(
            prepareBloc,
            zoneValues: <Object?, Object?>{_fakeAsyncZoneKey: async},
            zoneSpecification: ZoneSpecification(
              handleUncaughtError: (_, __, ___, error, stackTrace) =>
                  recordError(error, stackTrace),
            ),
          );
          runZonedGuarded(
            () {
              if (act != null) {
                try {
                  final actResult = act(targetBloc);
                  if (actResult is Future) {
                    unawaited(
                      actResult.then<void>((_) {}, onError: recordError),
                    );
                  }
                  // Intentional `on Object catch` (SCAR-ERR-02): capture any
                  // throwable from `act` so `errors` matcher can assert on it.
                } on Object catch (error, stackTrace) {
                  recordError(error, stackTrace);
                }
              }

              async.flushMicrotasks();

              if (wait != null) {
                async.elapse(wait);
              }
            },
            recordError,
            zoneValues: <Object?, Object?>{_fakeAsyncZoneKey: async},
          );
        });
      } finally {
        completer.complete();
      }
    } else {
      var pendingMicrotasks = 0;
      final microtaskSpec = ZoneSpecification(
        scheduleMicrotask: (self, parent, zone, f) {
          pendingMicrotasks++;
          parent.scheduleMicrotask(zone, () {
            pendingMicrotasks--;
            f();
          });
        },
      );
      try {
        final targetBloc = runZoned(
          prepareBloc,
          zoneSpecification: ZoneSpecification(
            scheduleMicrotask: microtaskSpec.scheduleMicrotask,
            handleUncaughtError: (_, __, ___, error, stackTrace) =>
                recordError(error, stackTrace),
          ),
        );
        unawaited(
          runZonedGuarded(
            () async {
              try {
                if (act != null) {
                  try {
                    final actResult = act(targetBloc);
                    if (actResult is Future) {
                      await actResult;
                    }
                    // Intentional `on Object catch` (SCAR-ERR-02): capture
                    // any throwable from `act` so `errors` matcher can assert
                    // on it.
                  } on Object catch (error, stackTrace) {
                    recordError(error, stackTrace);
                  }
                }

                if (wait != null) {
                  await Future<void>.delayed(Duration.zero);
                  await Future<void>.delayed(wait);
                } else {
                  while (pendingMicrotasks > 0) {
                    await Future<void>.microtask(() {});
                  }
                }
              } finally {
                if (!completer.isCompleted) {
                  completer.complete();
                }
              }
            },
            recordError,
            zoneSpecification: microtaskSpec,
          ),
        );
        await completer.future;
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    final targetBloc = bloc!;

    if (unhandledErrors.isNotEmpty) {
      final (error, stackTrace) = unhandledErrors.first;
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (expect != null) {
      final expectedStates = expect();
      final actualEmitted = states.skip(skip).toList();
      test_pkg.expect(actualEmitted, expectedStates);
    }

    if (errors != null) {
      final expectedErrors = errors();
      test_pkg.expect(caughtErrors, expectedErrors);
    }

    if (expectTelemetry != null) {
      final expectedTelemetry = expectTelemetry();
      test_pkg.expect(caughtTelemetry, expectedTelemetry);
    }

    if (expectComputed != null) {
      final expectedComputed = expectComputed(targetBloc);
      for (final entry in expectedComputed.entries) {
        test_pkg.expect(entry.key.value, entry.value);
      }
    }

    if (verify != null) {
      final verifyResult = verify(targetBloc);
      if (verifyResult is Future) {
        await verifyResult;
      }
    }
  } finally {
    try {
      disposeListener?.call();
      final builtBloc = bloc;
      if (builtBloc != null) {
        await builtBloc.close();
      }
    } finally {
      BlocSignalObserver.observer = baselineObserver;
      await tearDown?.call();
    }
  }
}

class _TestBlocSignalObserver extends BlocSignalObserver {
  _TestBlocSignalObserver({
    required this.onErrorCallback,
    this.onTelemetryCallback,
    this.parent,
  });

  final BlocSignalObserver? parent;
  final void Function(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) onErrorCallback;
  final void Function(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  })? onTelemetryCallback;

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    parent?.onCreate(bloc);
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    parent?.onEvent(bloc, event);
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEventCompleted(bloc, event);
    parent?.onEventCompleted(bloc, event);
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    parent?.onTransition(bloc, event, state);
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    parent?.onChange(bloc, change);
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    onErrorCallback(bloc, error, stackTrace);
    parent?.onError(bloc, error, stackTrace);
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    onTelemetryCallback?.call(bloc, name, event: event, metadata: metadata);
    parent?.onTelemetry(bloc, name, event: event, metadata: metadata);
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    parent?.onClose(bloc);
  }
}

/// A captured operational or diagnostic telemetry record emitted by a
/// [BlocSignalBase] container.
class BlocTelemetryEntry {
  /// Creates a [BlocTelemetryEntry].
  const BlocTelemetryEntry({
    required this.name,
    this.event,
    this.metadata,
  });

  /// The semantic name of the telemetry record.
  final String name;

  /// The optional associated event.
  final Object? event;

  /// The optional metadata map.
  final Map<String, dynamic>? metadata;

  @override
  String toString() =>
      'BlocTelemetryEntry(name: $name, event: $event, metadata: $metadata)';
}

/// A matcher that asserts a [BlocTelemetryEntry] matches the specified
/// [name], and optional [event] or [metadata].
///
/// When [metadata] is provided, the actual telemetry metadata must contain all
/// keys specified in [metadata] (subset match). Each metadata value can be
/// either a literal value or any [test_pkg.Matcher] predicate (including
/// collection matchers such as `contains` or `greaterThanOrEqualTo`).
///
/// ```dart
/// expectTelemetry: () => [
///   isTelemetry(
///     'event_dropped',
///     metadata: {'reason': 'in_flight', 'count': greaterThanOrEqualTo(1)},
///   ),
/// ];
/// ```
test_pkg.Matcher isTelemetry(
  String name, {
  Object? event,
  Map<String, dynamic>? metadata,
}) =>
    _IsTelemetryMatcher(name: name, event: event, metadata: metadata);

typedef _TelemetryMismatch = ({
  String reason,
  test_pkg.Matcher? nestedMatcher,
  Object? nestedActual,
  Map<dynamic, dynamic>? nestedState,
});

class _IsTelemetryMatcher extends test_pkg.Matcher {
  const _IsTelemetryMatcher({
    required this.name,
    this.event,
    this.metadata,
  });

  static final Object _mismatchKey = Object();

  final String name;
  final Object? event;
  final Map<String, dynamic>? metadata;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! BlocTelemetryEntry) {
      matchState[_mismatchKey] = (
        reason:
            'is not a BlocTelemetryEntry (actual type: ${item.runtimeType})',
        nestedMatcher: null,
        nestedActual: null,
        nestedState: null,
      );
      return false;
    }
    if (item.name != name) {
      matchState[_mismatchKey] = (
        reason: 'has name "${item.name}" instead of "$name"',
        nestedMatcher: null,
        nestedActual: null,
        nestedState: null,
      );
      return false;
    }

    final expectedEvent = event;
    if (expectedEvent != null) {
      final eventMatcher = test_pkg.wrapMatcher(expectedEvent);
      final eventState = <dynamic, dynamic>{};
      if (!eventMatcher.matches(item.event, eventState)) {
        matchState[_mismatchKey] = (
          reason: 'has mismatched event',
          nestedMatcher: eventMatcher,
          nestedActual: item.event,
          nestedState: eventState,
        );
        return false;
      }
    }

    final expectedMeta = metadata;
    if (expectedMeta != null) {
      final actualMeta = item.metadata;
      if (actualMeta == null) {
        matchState[_mismatchKey] = (
          reason: 'has null metadata',
          nestedMatcher: null,
          nestedActual: null,
          nestedState: null,
        );
        return false;
      }
      for (final entry in expectedMeta.entries) {
        if (!actualMeta.containsKey(entry.key)) {
          matchState[_mismatchKey] = (
            reason: 'is missing metadata key "${entry.key}"',
            nestedMatcher: null,
            nestedActual: null,
            nestedState: null,
          );
          return false;
        }
        final valueMatcher = test_pkg.wrapMatcher(entry.value);
        final valueState = <dynamic, dynamic>{};
        final actualValue = actualMeta[entry.key];
        if (!valueMatcher.matches(actualValue, valueState)) {
          matchState[_mismatchKey] = (
            reason: 'has mismatched metadata["${entry.key}"]',
            nestedMatcher: valueMatcher,
            nestedActual: actualValue,
            nestedState: valueState,
          );
          return false;
        }
      }
    }

    return true;
  }

  @override
  test_pkg.Description describe(test_pkg.Description description) {
    description.add('BlocTelemetryEntry(name: $name');
    if (event != null) {
      description
        ..add(', event: ')
        ..addDescriptionOf(event);
    }
    if (metadata != null) {
      description
        ..add(', metadata: ')
        ..addDescriptionOf(metadata);
    }
    return description.add(')');
  }

  @override
  test_pkg.Description describeMismatch(
    dynamic item,
    test_pkg.Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final mismatch = matchState[_mismatchKey] as _TelemetryMismatch?;
    if (mismatch != null) {
      mismatchDescription.add(mismatch.reason);
      final nestedMatcher = mismatch.nestedMatcher;
      if (nestedMatcher != null) {
        final nestedDescription = test_pkg.StringDescription();
        nestedMatcher.describeMismatch(
          mismatch.nestedActual,
          nestedDescription,
          mismatch.nestedState!,
          verbose,
        );
        if (nestedDescription.length > 0) {
          mismatchDescription
            ..add(': ')
            ..add(nestedDescription.toString());
        }
      }
      return mismatchDescription;
    }
    return super
        .describeMismatch(item, mismatchDescription, matchState, verbose);
  }
}
