import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc_signals/src/bloc_signal_mixin.dart';
import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:meta/meta.dart';

/// A recorded history entry for a container transition or error.
class DevToolsHistoryEntry {
  /// Creates a [DevToolsHistoryEntry].
  DevToolsHistoryEntry({
    required this.type,
    required this.timestamp,
    required this.data,
    this.instanceHashCode,
  });

  /// The type of entry ('transition', 'error', etc.).
  final String type;

  /// ISO 8601 timestamp string.
  final String timestamp;

  /// Structured payload data.
  final Map<String, dynamic> data;

  /// Optional container identity hash code.
  final int? instanceHashCode;

  /// Converts this entry to a JSON-serializable Map.
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp,
        'data': data,
        if (instanceHashCode != null) ...{
          'hashCode': instanceHashCode,
          'instanceHashCode': instanceHashCode,
        },
      };
}

/// Registry and service manager for Dart VM Service RPC extensions.
///
/// Automatically registers VM Service RPC extensions under `ext.bloc_signal.*`
/// for DevTools extension panels and inspection tooling:
/// - `ext.bloc_signal.getInstances`
/// - `ext.bloc_signal.getHistory`
/// - `ext.bloc_signal.dispatch`
///
/// Example:
/// ```dart
/// DevToolsService.instance.registerExtensions();
/// ```
class DevToolsService {
  DevToolsService._();

  /// The singleton instance of [DevToolsService].
  static final DevToolsService instance = DevToolsService._();

  /// Maximum allowed length for a `dispatch` RPC event payload (64 KB).
  static const int kMaxDispatchPayloadLength = 65536;

  final Map<int, WeakReference<BlocSignalBase<dynamic>>> _containers = {};
  final Map<int, List<DevToolsHistoryEntry>> _history = {};
  final Map<Type, Map<String, Object? Function(dynamic raw)>>
      _typedNamedDeserializers = {};
  final Map<Type, Object? Function(dynamic raw)> _typedDeserializers = {};
  final Map<String, Object? Function(dynamic raw)> _globalNamedDeserializers =
      {};
  late final Finalizer<int> _containerFinalizer = Finalizer<int>((id) {
    _containers.remove(id);
    _history.remove(id);
  });
  bool _extensionsRegistered = false;

  static bool _hasExplicitTypeBound<T extends BlocSignalBase<dynamic>>() =>
      T != (BlocSignalBase<dynamic>) && T != (BlocSignalBase<Object?>);

  /// Registers an event deserializer callback for containers of type [T]
  /// and/or a specific [eventName].
  ///
  /// Either an explicit container type [T] (not `BlocSignalBase`) or a non-null
  /// [eventName] must be provided. When [T] is explicitly provided, the
  /// deserializer is scoped strictly to containers of type [T] and will not
  /// resolve for other container types. When [T] is omitted and [eventName] is
  /// provided, the deserializer is registered as a global named fallback.
  ///
  /// ```dart
  /// DevToolsService.instance.registerEventDeserializer<CounterBloc>((raw) {
  ///   if (raw is Map && raw['action'] == 'increment') {
  ///     return IncrementEvent();
  ///   }
  ///   return raw;
  /// });
  /// ```
  void registerEventDeserializer<T extends BlocSignalBase<dynamic>>(
    Object? Function(dynamic raw) deserializer, {
    String? eventName,
  }) {
    assert(
      _hasExplicitTypeBound<T>() || eventName != null,
      'registerEventDeserializer requires an explicit container type <T> '
      'or a non-null eventName.',
    );
    if (_hasExplicitTypeBound<T>()) {
      if (eventName != null) {
        (_typedNamedDeserializers[T] ??= {})[eventName] = deserializer;
      } else {
        _typedDeserializers[T] = deserializer;
      }
      return;
    }

    if (eventName != null) {
      _globalNamedDeserializers[eventName] = deserializer;
    }
  }

  /// Unregisters a previously registered event deserializer for container type
  /// [T] and/or [eventName].
  ///
  /// Returns `true` if a registered deserializer was found and removed, or
  /// `false` if no matching deserializer was registered.
  ///
  /// ```dart
  /// final removed =
  ///     DevToolsService.instance.unregisterEventDeserializer<CounterBloc>();
  /// ```
  bool unregisterEventDeserializer<T extends BlocSignalBase<dynamic>>([
    String? eventName,
  ]) {
    if (_hasExplicitTypeBound<T>()) {
      if (eventName != null) {
        final scoped = _typedNamedDeserializers[T];
        if (scoped == null) return false;
        final removed = scoped.remove(eventName) != null;
        if (scoped.isEmpty) {
          _typedNamedDeserializers.remove(T);
        }
        return removed;
      }
      return _typedDeserializers.remove(T) != null;
    }

    if (eventName != null) {
      return _globalNamedDeserializers.remove(eventName) != null;
    }
    return _typedDeserializers.remove(T) != null;
  }

  /// Clears all registered event deserializers from [DevToolsService].
  ///
  /// Useful when resetting global state during application teardown or between
  /// unit test runs.
  ///
  /// ```dart
  /// DevToolsService.instance.clearEventDeserializers();
  /// ```
  void clearEventDeserializers() {
    _typedNamedDeserializers.clear();
    _typedDeserializers.clear();
    _globalNamedDeserializers.clear();
  }

  static bool get _inDebugMode {
    var inDebug = false;
    assert(
      () {
        inDebug = true;
        return true;
      }(),
      'Detecting debug mode',
    );
    return inDebug;
  }

  bool? _isEnabled;

  String? Function(BlocSignalBase<dynamic> bloc, Object? state)? _stateRedactor;
  String? Function(BlocSignalBase<dynamic> bloc, Object? event)? _eventRedactor;
  String? Function(BlocSignalBase<dynamic> bloc, Object error)? _errorRedactor;
  String Function(StackTrace stackTrace)? _stackTraceRedactor;
  int? _maxPayloadLength = 4096;

  /// Configures optional redactors and payload length limits used by
  /// [DevToolsService] and `DevToolsBlocSignalObserver`.
  ///
  /// - [stateRedactor]: Formats or redacts container state values; returning
  ///   `null` omits the state string.
  /// - [eventRedactor]: Formats or redacts event values; returning `null` omits
  ///   the event string.
  /// - [errorRedactor]: Formats or redacts error descriptions; returning `null`
  ///   omits the error string (falling back to `'[REDACTED]'` in RPC errors).
  /// - [stackTraceRedactor]: Formats or redacts stack traces.
  /// - [maxPayloadLength]: Maximum character length for recorded string
  ///   payloads (defaults to `4096`; `null` or `<= 0` disables truncation).
  void configure({
    String? Function(BlocSignalBase<dynamic> bloc, Object? state)?
        stateRedactor,
    String? Function(BlocSignalBase<dynamic> bloc, Object? event)?
        eventRedactor,
    String? Function(BlocSignalBase<dynamic> bloc, Object error)? errorRedactor,
    String Function(StackTrace stackTrace)? stackTraceRedactor,
    int? maxPayloadLength = 4096,
  }) {
    _stateRedactor = stateRedactor;
    _eventRedactor = eventRedactor;
    _errorRedactor = errorRedactor;
    _stackTraceRedactor = stackTraceRedactor;
    _maxPayloadLength = maxPayloadLength;
  }

  /// Truncates [value] to [maxLength] UTF-16 code units without splitting
  /// surrogate pairs, appending `'...[truncated]'` when exceeded.
  ///
  /// A `null` or non-positive [maxLength] disables truncation.
  static String truncatePayload(String value, int? maxLength) {
    if (maxLength == null || maxLength <= 0 || value.length <= maxLength) {
      return value;
    }
    var end = maxLength;
    final lastUnit = value.codeUnitAt(end - 1);
    if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
      end--;
    }
    return '${value.substring(0, end)}...[truncated]';
  }

  /// Formats and optionally redacts/truncates a container [state].
  String? formatState(BlocSignalBase<dynamic> bloc, Object? state) {
    final redactor = _stateRedactor;
    String? raw;
    if (redactor != null) {
      try {
        raw = redactor(bloc, state);
      } on Exception catch (_) {
        raw = '<redaction_error>';
      }
    } else {
      raw = state?.toString();
    }
    return raw != null ? truncatePayload(raw, _maxPayloadLength) : null;
  }

  /// Formats and optionally redacts/truncates an [event].
  String? formatEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    if (event == null) return null;
    final redactor = _eventRedactor;
    String? raw;
    if (redactor != null) {
      try {
        raw = redactor(bloc, event);
      } on Exception catch (_) {
        raw = '<redaction_error>';
      }
    } else {
      raw = event.toString();
    }
    return raw != null ? truncatePayload(raw, _maxPayloadLength) : null;
  }

  /// Formats and optionally redacts/truncates an [error].
  String? formatError(BlocSignalBase<dynamic> bloc, Object error) {
    final redactor = _errorRedactor;
    String? raw;
    if (redactor != null) {
      try {
        raw = redactor(bloc, error);
      } on Exception catch (_) {
        raw = '<redaction_error>';
      }
    } else {
      raw = error.toString();
    }
    return raw != null ? truncatePayload(raw, _maxPayloadLength) : null;
  }

  /// Formats and optionally redacts/truncates a [stackTrace].
  String formatStackTrace(StackTrace stackTrace) {
    final redactor = _stackTraceRedactor;
    String raw;
    if (redactor != null) {
      try {
        raw = redactor(stackTrace);
      } on Exception catch (_) {
        raw = '<redaction_error>';
      }
    } else {
      raw = stackTrace.toString();
    }
    return truncatePayload(raw, _maxPayloadLength);
  }

  /// Recursively sanitizes [metadata] into JSON-encodable values, converting
  /// `double.nan`, `double.infinity`, and `double.negativeInfinity` to strings
  /// and guarding against excessive nesting (`maxDepth = 8`) and cycles.
  Map<String, dynamic> sanitizeMetadata(Map<String, dynamic> metadata) {
    final visited = Set<Object>.identity();
    return _sanitizeValue(
      metadata,
      depth: 0,
      visited: visited,
      maxPayloadLength: _maxPayloadLength,
    ) as Map<String, dynamic>;
  }

  static dynamic _sanitizeValue(
    Object? value, {
    required int depth,
    required Set<Object> visited,
    required int? maxPayloadLength,
  }) {
    const maxDepth = 8;
    if (value == null || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      if (value.isNaN) return 'NaN';
      if (value == double.infinity) return 'Infinity';
      if (value == double.negativeInfinity) return '-Infinity';
      return value;
    }
    if (value is String) {
      return truncatePayload(value, maxPayloadLength);
    }
    if (value is Map) {
      if (depth >= maxDepth || !visited.add(value)) {
        return '<max_depth_or_cycle>';
      }
      try {
        return <String, dynamic>{
          for (final entry in value.entries)
            truncatePayload(entry.key.toString(), maxPayloadLength):
                _sanitizeValue(
              entry.value,
              depth: depth + 1,
              visited: visited,
              maxPayloadLength: maxPayloadLength,
            ),
        };
      } finally {
        visited.remove(value);
      }
    }
    if (value is Iterable) {
      if (depth >= maxDepth || !visited.add(value)) {
        return '<max_depth_or_cycle>';
      }
      try {
        return value
            .map(
              (e) => _sanitizeValue(
                e,
                depth: depth + 1,
                visited: visited,
                maxPayloadLength: maxPayloadLength,
              ),
            )
            .toList();
      } finally {
        visited.remove(value);
      }
    }
    return truncatePayload(value.toString(), maxPayloadLength);
  }

  /// Whether DevTools history tracking and extension registration are enabled.
  ///
  /// Defaults to `true` in debug mode (asserts enabled) and is forced to
  /// `false` in release builds to eliminate runtime history retention and
  /// allocation overhead.
  bool get isEnabled => _inDebugMode && (_isEnabled ?? true);

  set isEnabled(bool value) {
    if (!_inDebugMode) return;
    _isEnabled = value;
  }

  /// Registers VM Service RPC extensions if running under VM service
  /// inspection.
  void registerExtensions() {
    if (_extensionsRegistered || !isEnabled || !_inDebugMode) return;
    developer.registerExtension(
      'ext.bloc_signal.getInstances',
      handleGetInstances,
    );
    developer.registerExtension(
      'ext.bloc_signal.getHistory',
      handleGetHistory,
    );
    developer.registerExtension(
      'ext.bloc_signal.dispatch',
      handleDispatch,
    );
    _extensionsRegistered = true;
  }

  /// Tracks container creation.
  void trackCreate(BlocSignalBase<dynamic> bloc) {
    if (!isEnabled) return;
    registerExtensions();
    final id = identityHashCode(bloc);
    _containers[id] = WeakReference(bloc);
    _history[id] ??= [];
    _containerFinalizer.attach(bloc, id, detach: bloc);
  }

  /// Tracks container transition.
  void trackTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state, {
    String? formattedEvent,
    bool hasFormattedEvent = false,
    String? formattedCurrentState,
    bool hasFormattedCurrentState = false,
    String? formattedNextState,
    bool hasFormattedNextState = false,
  }) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _record(
      id,
      DevToolsHistoryEntry(
        type: 'transition',
        timestamp: DateTime.now().toIso8601String(),
        instanceHashCode: id,
        data: {
          'event':
              hasFormattedEvent ? formattedEvent : formatEvent(bloc, event),
          'currentState': hasFormattedCurrentState
              ? formattedCurrentState
              : formatState(bloc, bloc.stateValue),
          'nextState': hasFormattedNextState
              ? formattedNextState
              : formatState(bloc, state),
        },
      ),
    );
  }

  /// Tracks container error.
  void trackError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace, {
    String? formattedError,
    bool hasFormattedError = false,
    String? formattedStackTrace,
    bool hasFormattedStackTrace = false,
  }) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _record(
      id,
      DevToolsHistoryEntry(
        type: 'error',
        timestamp: DateTime.now().toIso8601String(),
        instanceHashCode: id,
        data: {
          'error':
              hasFormattedError ? formattedError : formatError(bloc, error),
          'stackTrace': hasFormattedStackTrace
              ? formattedStackTrace
              : formatStackTrace(stackTrace),
        },
      ),
    );
  }

  /// Tracks container telemetry.
  void trackTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
    String? formattedEvent,
    bool hasFormattedEvent = false,
    bool metadataSanitized = false,
  }) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    final safeMeta = metadata == null
        ? null
        : (metadataSanitized ? metadata : sanitizeMetadata(metadata));
    _record(
      id,
      DevToolsHistoryEntry(
        type: 'telemetry',
        timestamp: DateTime.now().toIso8601String(),
        instanceHashCode: id,
        data: {
          'name': name,
          'event':
              hasFormattedEvent ? formattedEvent : formatEvent(bloc, event),
          'metadata': safeMeta,
        },
      ),
    );
  }

  /// Tracks container closure.
  void trackClose(BlocSignalBase<dynamic> bloc) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _containerFinalizer.detach(bloc);
    _containers.remove(id);
    _history.remove(id);
  }

  /// Resets all tracked containers, history, deserializers, and enabled state
  /// for unit tests.
  @visibleForTesting
  void reset() {
    for (final ref in _containers.values) {
      final target = ref.target;
      if (target != null) {
        _containerFinalizer.detach(target);
      }
    }
    _containers.clear();
    _history.clear();
    clearEventDeserializers();
    _isEnabled = null;
    _stateRedactor = null;
    _eventRedactor = null;
    _errorRedactor = null;
    _stackTraceRedactor = null;
    _maxPayloadLength = 4096;
  }

  /// Returns recorded history entries for [id] in unit tests.
  @visibleForTesting
  List<DevToolsHistoryEntry>? getHistoryForTest(int id) => _history[id];

  void _record(int hashCode, DevToolsHistoryEntry entry) {
    final list = _history[hashCode];
    if (list != null) {
      list.add(entry);
      if (list.length > 100) list.removeAt(0);
    }
  }

  /// RPC Handler: `ext.bloc_signal.getInstances`
  Future<developer.ServiceExtensionResponse> handleGetInstances(
    String method,
    Map<String, String> parameters,
  ) async {
    if (!isEnabled) {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'instances': <Map<String, dynamic>>[]}),
      );
    }
    final instances = <Map<String, dynamic>>[];
    _containers.removeWhere((id, ref) {
      final bloc = ref.target;
      if (bloc == null) {
        _history.remove(id);
        return true;
      }
      instances.add({
        'hashCode': id,
        'type': bloc.runtimeType.toString(),
        'stateValue': formatState(bloc, bloc.stateValue),
        'isClosed': bloc.isClosed,
      });
      return false;
    });

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'instances': instances}),
    );
  }

  /// RPC Handler: `ext.bloc_signal.getHistory`
  Future<developer.ServiceExtensionResponse> handleGetHistory(
    String method,
    Map<String, String> parameters,
  ) async {
    if (!isEnabled) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'DevToolsService is disabled',
      );
    }
    final idStr = parameters['hashCode'];
    if (idStr == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing hashCode parameter',
      );
    }
    final id = int.tryParse(idStr);
    final history = _history[id];
    if (history == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Instance not found for hashCode $idStr',
      );
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'history': history.map((e) => e.toJson()).toList()}),
    );
  }

  Object? Function(dynamic raw)? _resolveDeserializer(
    Type containerType,
    Map<String, String> parameters,
    dynamic eventPayload,
  ) {
    final paramEventName = parameters['eventName'];
    String? payloadEventName;
    if (eventPayload is Map) {
      final rawName = eventPayload['event'] ??
          eventPayload['type'] ??
          eventPayload['name'] ??
          eventPayload['action'];
      if (rawName is String) {
        payloadEventName = rawName;
      }
    }

    final typedNamed = _typedNamedDeserializers[containerType];
    if (typedNamed != null) {
      if (paramEventName != null && typedNamed[paramEventName] != null) {
        return typedNamed[paramEventName];
      }
      if (payloadEventName != null && typedNamed[payloadEventName] != null) {
        return typedNamed[payloadEventName];
      }
    }

    final typed = _typedDeserializers[containerType];
    if (typed != null) return typed;

    if (paramEventName != null) {
      final byParam = _globalNamedDeserializers[paramEventName];
      if (byParam != null) return byParam;
    }
    if (payloadEventName != null) {
      return _globalNamedDeserializers[payloadEventName];
    }

    return null;
  }

  /// RPC Handler: `ext.bloc_signal.dispatch`
  Future<developer.ServiceExtensionResponse> handleDispatch(
    String method,
    Map<String, String> parameters,
  ) async {
    if (!isEnabled) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'DevToolsService is disabled',
      );
    }
    final idStr = parameters['hashCode'];
    final eventStr = parameters['event'];
    if (idStr == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing hashCode parameter',
      );
    }
    if (eventStr == null || eventStr.isEmpty) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing or empty event parameter',
      );
    }
    if (eventStr.length > kMaxDispatchPayloadLength) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Event payload exceeds maximum length of '
        '$kMaxDispatchPayloadLength characters',
      );
    }
    final id = int.tryParse(idStr);
    final bloc = _containers[id]?.target;
    if (bloc == null || bloc.isClosed) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Target container not found or closed',
      );
    }
    if (bloc is! BlocSignalMixin<dynamic, dynamic>) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Target container ${bloc.runtimeType} does not support event dispatch',
      );
    }

    dynamic eventPayload = eventStr;
    final trimmed = eventStr.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        eventPayload = jsonDecode(trimmed);
      } on FormatException catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Invalid JSON event payload: ${e.message}',
        );
      }
    }

    final deserializer = _resolveDeserializer(
      bloc.runtimeType,
      parameters,
      eventPayload,
    );
    if (deserializer != null) {
      try {
        eventPayload = deserializer(eventPayload);
        // Intentional `on Object catch` (SCAR-ERR-02): VM Service RPC
        // extensions must return a structured JSON-RPC error response rather
        // than crashing the target isolate if a custom deserializer throws
        // `TypeError` or `StateError`.
      } on Object catch (e) {
        final redactedError = formatError(bloc, e) ?? '[REDACTED]';
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Failed to deserialize event for ${bloc.runtimeType}: $redactedError',
        );
      }
    }

    try {
      bloc.add(eventPayload);
      // Intentional `on Object catch` (SCAR-ERR-02): VM Service RPC
      // extensions must return a structured JSON-RPC error response rather
      // than crashing the target isolate when dispatching an invalid or
      // unregistered event throws `TypeError` or `StateError`.
    } on Object catch (e) {
      final redactedError = formatError(bloc, e) ?? '[REDACTED]';
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Failed to dispatch event to ${bloc.runtimeType}: $redactedError',
      );
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'success': true,
        'stateValue': formatState(bloc, bloc.stateValue),
      }),
    );
  }
}
