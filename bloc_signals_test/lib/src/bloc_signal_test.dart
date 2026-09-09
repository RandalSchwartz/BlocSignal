import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart' as test_pkg;

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
/// [setUp] is an optional callback invoked prior to building the state
/// container.
///
/// [act] is an optional callback invoked after construction to trigger
/// events or methods.
///
/// [skip] is an optional `int` that defaults to 0 and defines how many
/// emitted states should be skipped from the expectation list.
///
/// [wait] is an optional [Duration] to await after [act] before checking
/// expectations.
///
/// [expect] is an optional callback returning an [Iterable] or
/// [test_pkg.Matcher] of expected states.
///
/// [verify] is an optional callback invoked after expectations are verified.
///
/// [errors] is an optional callback returning an [Iterable] or
/// [test_pkg.Matcher] of expected errors.
///
/// [expectTelemetry] is an optional callback returning an [Iterable] or
/// [test_pkg.Matcher] of expected telemetry records (such as [isTelemetry]).
///
/// [tearDown] is an optional callback invoked after test completion.
@isTest
void blocSignalTest<B extends BlocSignalBase<State>, State>(
  String description, {
  required B Function() build,
  FutureOr<void> Function()? setUp,
  FutureOr<void> Function(B bloc)? act,
  Duration? wait,
  int skip = 0,
  Object? Function()? expect,
  FutureOr<void> Function(B bloc)? verify,
  Object? Function()? errors,
  Object? Function()? expectTelemetry,
  FutureOr<void> Function()? tearDown,
  dynamic tags,
}) {
  test_pkg.test(
    description,
    () async {
      await setUp?.call();
      final states = <State>[];
      final caughtErrors = <Object>[];
      final caughtTelemetry = <BlocTelemetryEntry>[];
      B? bloc;

      final previousObserver = BlocSignalObserver.observer;
      final initialErrors = <(Object, Object)>[];
      final initialTelemetry = <(Object, BlocTelemetryEntry)>[];

      final testObserver = _TestBlocSignalObserver(
        parent: previousObserver,
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

      void Function()? disposeListener;
      try {
        bloc = build();
        for (final pair in initialErrors) {
          if (identical(pair.$1, bloc)) {
            caughtErrors.add(pair.$2);
          }
        }
        for (final pair in initialTelemetry) {
          if (identical(pair.$1, bloc)) {
            caughtTelemetry.add(pair.$2);
          }
        }

        var initialSkipped = false;
        disposeListener = bloc.state.subscribe((value) {
          if (!initialSkipped) {
            initialSkipped = true;
            return;
          }
          states.add(value);
        });

        if (act != null) {
          final actResult = act(bloc);
          if (actResult is Future) {
            await actResult;
          }
        }

        if (wait != null) {
          await Future<void>.delayed(wait);
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

        if (verify != null) {
          final verifyResult = verify(bloc);
          if (verifyResult is Future) {
            await verifyResult;
          }
        }
      } finally {
        disposeListener?.call();
        if (bloc != null) {
          await bloc.close();
        }
        BlocSignalObserver.observer = previousObserver;
        await tearDown?.call();
      }
    },
    tags: tags,
  );
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
/// key-value pairs specified in [metadata] (subset match).
///
/// ```dart
/// expectTelemetry: () => [
///   isTelemetry(
///     'event_dropped',
///     metadata: {'reason': 'in_flight'},
///   ),
/// ];
/// ```
test_pkg.Matcher isTelemetry(
  String name, {
  Object? event,
  Map<String, dynamic>? metadata,
}) =>
    _IsTelemetryMatcher(name: name, event: event, metadata: metadata);

class _IsTelemetryMatcher extends test_pkg.Matcher {
  const _IsTelemetryMatcher({
    required this.name,
    this.event,
    this.metadata,
  });

  final String name;
  final Object? event;
  final Map<String, dynamic>? metadata;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! BlocTelemetryEntry) return false;
    if (item.name != name) return false;

    final expectedEvent = event;
    if (expectedEvent != null) {
      final eventMatcher = test_pkg.wrapMatcher(expectedEvent);
      if (!eventMatcher.matches(item.event, matchState)) return false;
    }

    final expectedMeta = metadata;
    if (expectedMeta != null) {
      final actualMeta = item.metadata;
      if (actualMeta == null) return false;
      for (final entry in expectedMeta.entries) {
        if (!actualMeta.containsKey(entry.key) ||
            actualMeta[entry.key] != entry.value) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  test_pkg.Description describe(test_pkg.Description description) {
    description.add('BlocTelemetryEntry(name: $name');
    if (event != null) description.add(', event: $event');
    if (metadata != null) description.add(', metadata: $metadata');
    return description.add(')');
  }
}
