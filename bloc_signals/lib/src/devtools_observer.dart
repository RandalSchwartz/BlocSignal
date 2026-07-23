import 'dart:developer' as developer;

import 'package:bloc_signals/src/bloc_signals_base.dart';

/// A [BlocSignalObserver] that broadcasts container lifecycle events to the
/// Dart VM service via [developer.postEvent] under `bloc_signal.*` event kinds.
///
/// This provides foundational telemetry for Dart and Flutter DevTools
/// extensions and VM service inspection tools across both pure Dart and
/// Flutter applications.
class DevToolsBlocSignalObserver extends BlocSignalObserver {
  /// Creates a [DevToolsBlocSignalObserver], optionally chaining calls to
  /// [previousObserver].
  DevToolsBlocSignalObserver({this.previousObserver});

  /// An optional parent observer to delegate calls to.
  final BlocSignalObserver? previousObserver;

  void _post(String eventKind, Map<String, dynamic> eventData) {
    assert(
      () {
        developer.postEvent(eventKind, eventData);
        return true;
      }(),
      'Failed to post DevTools event',
    );
  }

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    super.onCreate(bloc);
    previousObserver?.onCreate(bloc);

    _post('bloc_signal.onCreate', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': bloc.hashCode,
      'initialState': bloc.stateValue.toString(),
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    previousObserver?.onEvent(bloc, event);

    _post('bloc_signal.onEvent', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': bloc.hashCode,
      'event': event.toString(),
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    previousObserver?.onTransition(bloc, event, state);

    _post('bloc_signal.onTransition', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': bloc.hashCode,
      'event': event?.toString(),
      'nextState': state.toString(),
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }

  @override
  void onChange(
    BlocSignalBase<dynamic> bloc,
    Change<dynamic> change,
  ) {
    super.onChange(bloc, change);
    previousObserver?.onChange(bloc, change);

    _post('bloc_signal.onChange', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': bloc.hashCode,
      'currentState': change.currentState.toString(),
      'nextState': change.nextState.toString(),
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    previousObserver?.onError(bloc, error, stackTrace);

    _post('bloc_signal.onError', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': bloc.hashCode,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);
    previousObserver?.onClose(bloc);

    _post('bloc_signal.onClose', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': bloc.hashCode,
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }
}
