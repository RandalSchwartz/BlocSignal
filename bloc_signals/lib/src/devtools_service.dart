import 'dart:convert';
import 'dart:developer' as developer;

import 'package:bloc_signals/src/bloc_signals_base.dart';

/// A recorded history entry for a container transition or error.
class DevToolsHistoryEntry {
  /// Creates a [DevToolsHistoryEntry].
  DevToolsHistoryEntry({
    required this.type,
    required this.timestamp,
    required this.data,
  });

  /// The type of entry ('transition', 'error', etc.).
  final String type;

  /// ISO 8601 timestamp string.
  final String timestamp;

  /// Structured payload data.
  final Map<String, dynamic> data;

  /// Converts this entry to a JSON-serializable Map.
  Map<String, dynamic> toJson() => {
        'type': type,
        'timestamp': timestamp,
        'data': data,
      };
}

/// Registry and service manager for Dart VM Service RPC extensions.
class DevToolsService {
  DevToolsService._();

  /// The singleton instance of [DevToolsService].
  static final DevToolsService instance = DevToolsService._();

  final Map<int, WeakReference<BlocSignalBase<dynamic>>> _containers = {};
  final Map<int, List<DevToolsHistoryEntry>> _history = {};
  bool _extensionsRegistered = false;

  /// Registers VM Service RPC extensions if running under VM service
  /// inspection.
  void registerExtensions() {
    if (_extensionsRegistered) return;
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
    registerExtensions();
    _containers[bloc.hashCode] = WeakReference(bloc);
    _history[bloc.hashCode] ??= [];
  }

  /// Tracks container transition.
  void trackTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    _record(
      bloc.hashCode,
      DevToolsHistoryEntry(
        type: 'transition',
        timestamp: DateTime.now().toIso8601String(),
        data: {
          'event': event?.toString(),
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
    _record(
      bloc.hashCode,
      DevToolsHistoryEntry(
        type: 'error',
        timestamp: DateTime.now().toIso8601String(),
        data: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      ),
    );
  }

  /// Tracks container closure.
  void trackClose(BlocSignalBase<dynamic> bloc) {
    _containers.remove(bloc.hashCode);
    _history.remove(bloc.hashCode);
  }

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

    if (eventStr != null && bloc is BlocSignal<dynamic, dynamic>) {
      bloc.add(eventStr);
    }

    return developer.ServiceExtensionResponse.result(
      jsonEncode({'success': true, 'stateValue': bloc.stateValue.toString()}),
    );
  }
}
