import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart' as test_pkg;

/// Declaratively tests a [BlocSignalBase] instance.
///
/// [blocSignalTest] creates a new test case with the given [description].
///
/// [build] should construct and return the state container instance under
/// test.
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
  FutureOr<void> Function()? tearDown,
  dynamic tags,
}) {
  test_pkg.test(
    description,
    () async {
      await setUp?.call();
      final states = <State>[];
      final caughtErrors = <Object>[];
      B? bloc;

      final previousObserver = BlocSignalObserver.observer;
      final testObserver = _TestBlocSignalObserver(
        parent: previousObserver,
        onErrorCallback: (b, error, stackTrace) {
          if (identical(b, bloc)) {
            caughtErrors.add(error);
          }
        },
      );
      BlocSignalObserver.observer = testObserver;

      void Function()? disposeListener;
      try {
        bloc = build();

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
    this.parent,
  });

  final BlocSignalObserver? parent;
  final void Function(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) onErrorCallback;

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
  void onClose(BlocSignalBase<dynamic> bloc) {
    parent?.onClose(bloc);
  }
}
