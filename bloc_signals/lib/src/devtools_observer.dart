import 'dart:developer' as developer;

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:bloc_signals/src/devtools_service.dart';

/// A [BlocSignalObserver] that broadcasts container lifecycle events to the
/// Dart VM service via [developer.postEvent] under `bloc_signal.*` event kinds
/// and registers VM Service RPC extensions via [DevToolsService].
///
/// Example:
/// ```dart
/// void main() {
///   BlocSignalObserver.observer = DevToolsBlocSignalObserver(
///     previousObserver: MyLoggerObserver(),
///   );
///   runApp(const MyApp());
/// }
/// ```
class DevToolsBlocSignalObserver extends BlocSignalObserver {
  /// Creates a [DevToolsBlocSignalObserver], optionally chaining calls to
  /// [previousObserver].
  DevToolsBlocSignalObserver({this.previousObserver});

  /// An optional parent observer to delegate calls to.
  final BlocSignalObserver? previousObserver;

  void _post(String eventKind, Map<String, dynamic> eventData) {
    if (!DevToolsService.instance.isEnabled) return;
    developer.postEvent(eventKind, eventData);
  }

  void _forwardPrevious(
    BlocSignalBase<dynamic> bloc,
    void Function(BlocSignalObserver observer) action,
  ) {
    final previous = previousObserver;
    if (previous == null) return;
    try {
      action(previous);
    } on Exception catch (e, stackTrace) {
      // Isolate previousObserver exceptions via the container's error handler.
      // ignore: invalid_use_of_protected_member
      bloc.onError(e, stackTrace);
    }
  }

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    super.onCreate(bloc);
    DevToolsService.instance.trackCreate(bloc);
    _forwardPrevious(bloc, (observer) => observer.onCreate(bloc));

    if (DevToolsService.instance.isEnabled) {
      _post('bloc_signal.onCreate', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'initialState': bloc.stateValue.toString(),
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    _forwardPrevious(bloc, (observer) => observer.onEvent(bloc, event));

    if (DevToolsService.instance.isEnabled) {
      _post('bloc_signal.onEvent', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'event': event.toString(),
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEventCompleted(bloc, event);
    _forwardPrevious(
      bloc,
      (observer) => observer.onEventCompleted(bloc, event),
    );
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    DevToolsService.instance.trackTransition(bloc, event, state);
    _forwardPrevious(
      bloc,
      (observer) => observer.onTransition(bloc, event, state),
    );

    if (DevToolsService.instance.isEnabled) {
      _post('bloc_signal.onTransition', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'event': event?.toString(),
        'currentState': bloc.stateValue.toString(),
        'nextState': state.toString(),
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  @override
  void onChange(
    BlocSignalBase<dynamic> bloc,
    Change<dynamic> change,
  ) {
    super.onChange(bloc, change);
    _forwardPrevious(bloc, (observer) => observer.onChange(bloc, change));

    if (DevToolsService.instance.isEnabled) {
      _post('bloc_signal.onChange', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'currentState': change.currentState.toString(),
        'nextState': change.nextState.toString(),
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    DevToolsService.instance.trackError(bloc, error, stackTrace);
    try {
      previousObserver?.onError(bloc, error, stackTrace);
    } on Exception catch (_) {
      // Prevent previousObserver exception in onError from causing recursion
    }

    if (DevToolsService.instance.isEnabled) {
      _post('bloc_signal.onError', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);
    DevToolsService.instance.trackClose(bloc);
    _forwardPrevious(bloc, (observer) => observer.onClose(bloc));

    if (DevToolsService.instance.isEnabled) {
      _post('bloc_signal.onClose', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'timestamp': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    super.onTelemetry(bloc, name, event: event, metadata: metadata);
    if (!DevToolsService.instance.isEnabled) {
      _forwardPrevious(
        bloc,
        (observer) => observer.onTelemetry(
          bloc,
          name,
          event: event,
          metadata: metadata,
        ),
      );
      return;
    }
    final sanitizedMeta = metadata != null ? _sanitizeMetadata(metadata) : null;
    DevToolsService.instance.trackTelemetry(
      bloc,
      name,
      event: event,
      metadata: sanitizedMeta,
    );
    _forwardPrevious(
      bloc,
      (observer) => observer.onTelemetry(
        bloc,
        name,
        event: event,
        metadata: metadata,
      ),
    );

    _post('bloc_signal.onTelemetry', {
      'blocType': bloc.runtimeType.toString(),
      'hashCode': identityHashCode(bloc),
      'name': name,
      'event': event?.toString(),
      'metadata': sanitizedMeta,
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }

  static Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
    final sanitized = <String, dynamic>{};
    for (final entry in metadata.entries) {
      final value = entry.value;
      if (value == null || value is num || value is bool || value is String) {
        sanitized[entry.key] = value;
      } else if (value is Map) {
        sanitized[entry.key] = value.map(
          (k, v) => MapEntry(k.toString(), v?.toString()),
        );
      } else if (value is Iterable) {
        sanitized[entry.key] = value.map((e) => e?.toString()).toList();
      } else {
        sanitized[entry.key] = value.toString();
      }
    }
    return sanitized;
  }
}
