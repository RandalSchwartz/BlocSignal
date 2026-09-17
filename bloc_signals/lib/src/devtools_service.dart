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

  final Map<int, WeakReference<BlocSignalBase<dynamic>>> _containers = {};
  final Map<int, List<DevToolsHistoryEntry>> _history = {};
  final Map<Type, Object? Function(dynamic raw)> _eventDeserializers = {};
  bool _extensionsRegistered = false;

  /// Registers an event deserializer callback for containers of type [T].
  ///
  /// This allows the DevTools `dispatch` RPC to reconstruct typed events from
  /// JSON maps or strings when interacting with strongly-typed blocs.
  void registerEventDeserializer<T extends BlocSignalBase<dynamic>>(
    Object? Function(dynamic raw) deserializer,
  ) {
    _eventDeserializers[T] = deserializer;
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

  /// Whether DevTools history tracking and extension registration are enabled.
  ///
  /// Defaults to `true` in debug mode (asserts enabled) and `false` in release
  /// builds to eliminate runtime history retention and allocation overhead.
  bool get isEnabled => _isEnabled ?? _inDebugMode;

  set isEnabled(bool value) {
    _isEnabled = value;
  }

  /// Registers VM Service RPC extensions if running under VM service
  /// inspection.
  void registerExtensions() {
    if (_extensionsRegistered || !isEnabled) return;
    assert(
      () {
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
        return true;
      }(),
      'Failed to register DevTools VM Service RPC extensions',
    );
  }

  /// Tracks container creation.
  void trackCreate(BlocSignalBase<dynamic> bloc) {
    if (!isEnabled) return;
    registerExtensions();
    final id = identityHashCode(bloc);
    _containers[id] = WeakReference(bloc);
    _history[id] ??= [];
  }

  /// Tracks container transition.
  void trackTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _record(
      id,
      DevToolsHistoryEntry(
        type: 'transition',
        timestamp: DateTime.now().toIso8601String(),
        instanceHashCode: id,
        data: {
          'event': event?.toString(),
          'currentState': bloc.stateValue.toString(),
          'nextState': state?.toString(),
        },
      ),
    );
  }

  /// Tracks container error.
  void trackError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _record(
      id,
      DevToolsHistoryEntry(
        type: 'error',
        timestamp: DateTime.now().toIso8601String(),
        instanceHashCode: id,
        data: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
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
  }) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _record(
      id,
      DevToolsHistoryEntry(
        type: 'telemetry',
        timestamp: DateTime.now().toIso8601String(),
        instanceHashCode: id,
        data: {
          'name': name,
          'event': event?.toString(),
          'metadata': metadata,
        },
      ),
    );
  }

  /// Tracks container closure.
  void trackClose(BlocSignalBase<dynamic> bloc) {
    if (!isEnabled) return;
    final id = identityHashCode(bloc);
    _containers.remove(id);
    _history.remove(id);
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
    final instances = <Map<String, dynamic>>[];
    _containers.removeWhere((id, ref) {
      final bloc = ref.target;
      if (bloc == null) return true;
      instances.add({
        'hashCode': id,
        'type': bloc.runtimeType.toString(),
        'stateValue': bloc.stateValue.toString(),
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

  /// RPC Handler: `ext.bloc_signal.dispatch`
  Future<developer.ServiceExtensionResponse> handleDispatch(
    String method,
    Map<String, String> parameters,
  ) async {
    final idStr = parameters['hashCode'];
    final eventStr = parameters['event'];
    if (idStr == null) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.invalidParams,
        'Missing hashCode parameter',
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

    if (eventStr != null && bloc is BlocSignalMixin<dynamic, dynamic>) {
      dynamic eventPayload = eventStr;
      if (eventStr.startsWith('{') || eventStr.startsWith('[')) {
        try {
          eventPayload = jsonDecode(eventStr);
        } on FormatException catch (e) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Invalid JSON event payload: ${e.message}',
          );
        }
      }

      final deserializer = _eventDeserializers[bloc.runtimeType];
      if (deserializer != null) {
        try {
          eventPayload = deserializer(eventPayload);
        } on Object catch (e) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Failed to deserialize event for ${bloc.runtimeType}: $e',
          );
        }
      }

      try {
        bloc.add(eventPayload);
      } on Object catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Failed to dispatch event to ${bloc.runtimeType}: $e',
        );
      }
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'success': true, 'stateValue': bloc.stateValue.toString()}),
    );
  }
}
