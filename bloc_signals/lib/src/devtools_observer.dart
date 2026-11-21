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
  /// [previousObserver] and configuring redaction and payload truncation.
  DevToolsBlocSignalObserver({
    this.previousObserver,
    this.stateRedactor,
    this.eventRedactor,
    this.errorRedactor,
    this.stackTraceRedactor,
    this.maxPayloadLength = 4096,
  }) {
    DevToolsService.instance.configure(
      stateRedactor: stateRedactor,
      eventRedactor: eventRedactor,
      errorRedactor: errorRedactor,
      stackTraceRedactor: stackTraceRedactor,
      maxPayloadLength: maxPayloadLength,
    );
  }

  /// An optional parent observer to delegate calls to.
  final BlocSignalObserver? previousObserver;

  /// Optional callback to redact or format state values before recording them.
  final String? Function(BlocSignalBase<dynamic> bloc, Object? state)?
      stateRedactor;

  /// Optional callback to redact or format event values before recording them.
  final String? Function(BlocSignalBase<dynamic> bloc, Object? event)?
      eventRedactor;

  /// Optional callback to redact or format error descriptions before recording
  /// them.
  final String? Function(BlocSignalBase<dynamic> bloc, Object error)?
      errorRedactor;

  /// Optional callback to redact or format stack traces before recording them.
  final String Function(StackTrace stackTrace)? stackTraceRedactor;

  /// Maximum character length for recorded string payloads.
  ///
  /// Defaults to `4096`. Setting to `null` or a non-positive value disables
  /// truncation.
  final int? maxPayloadLength;

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
        'initialState': DevToolsService.instance.formatState(
          bloc,
          bloc.stateValue,
        ),
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
        'event': DevToolsService.instance.formatEvent(bloc, event),
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
    final enabled = DevToolsService.instance.isEnabled;
    final eventStr =
        enabled ? DevToolsService.instance.formatEvent(bloc, event) : null;
    final currentStateStr = enabled
        ? DevToolsService.instance.formatState(bloc, bloc.stateValue)
        : null;
    final nextStateStr =
        enabled ? DevToolsService.instance.formatState(bloc, state) : null;

    if (enabled) {
      DevToolsService.instance.trackTransition(
        bloc,
        event,
        state,
        formattedEvent: eventStr,
        hasFormattedEvent: true,
        formattedCurrentState: currentStateStr,
        hasFormattedCurrentState: true,
        formattedNextState: nextStateStr,
        hasFormattedNextState: true,
      );
    }
    _forwardPrevious(
      bloc,
      (observer) => observer.onTransition(bloc, event, state),
    );

    if (enabled) {
      _post('bloc_signal.onTransition', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'event': eventStr,
        'currentState': currentStateStr,
        'nextState': nextStateStr,
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
        'currentState': DevToolsService.instance.formatState(
          bloc,
          change.currentState,
        ),
        'nextState': DevToolsService.instance.formatState(
          bloc,
          change.nextState,
        ),
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
    final enabled = DevToolsService.instance.isEnabled;
    final errorStr =
        enabled ? DevToolsService.instance.formatError(bloc, error) : null;
    final stackTraceStr =
        enabled ? DevToolsService.instance.formatStackTrace(stackTrace) : null;

    if (enabled) {
      DevToolsService.instance.trackError(
        bloc,
        error,
        stackTrace,
        formattedError: errorStr,
        hasFormattedError: true,
        formattedStackTrace: stackTraceStr,
        hasFormattedStackTrace: true,
      );
    }
    try {
      previousObserver?.onError(bloc, error, stackTrace);
    } on Exception catch (_) {
      // Prevent previousObserver exception in onError from causing recursion
    }

    if (enabled) {
      _post('bloc_signal.onError', {
        'blocType': bloc.runtimeType.toString(),
        'hashCode': identityHashCode(bloc),
        'error': errorStr,
        'stackTrace': stackTraceStr,
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
    final sanitizedMeta = metadata != null
        ? DevToolsService.instance.sanitizeMetadata(metadata)
        : null;
    final eventStr = DevToolsService.instance.formatEvent(bloc, event);
    DevToolsService.instance.trackTelemetry(
      bloc,
      name,
      event: event,
      metadata: sanitizedMeta,
      formattedEvent: eventStr,
      hasFormattedEvent: true,
      metadataSanitized: true,
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
      'event': eventStr,
      'metadata': sanitizedMeta,
      'timestamp': DateTime.now().microsecondsSinceEpoch,
    });
  }
}
