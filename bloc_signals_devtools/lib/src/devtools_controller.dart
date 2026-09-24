import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' as vm;

/// Callback signature for invoking a Dart VM service extension RPC method.
typedef DevToolsExtensionRpcCaller = Future<Map<String, dynamic>> Function(
  String method, [
  Map<String, dynamic>? args,
]);

/// Manages live VM service extension communication, instance caching,
/// event streaming, and debounced telemetry for `BlocSignal` DevTools
/// inspector.
///
/// Example:
/// ```dart
/// final controller = BlocSignalsDevToolsController(
///   callExtensionRpc: (method, [args]) async => {'instances': []},
/// );
/// await controller.fetchInstances();
/// controller.dispose();
/// ```
class BlocSignalsDevToolsController with ChangeNotifier {
  /// Creates a [BlocSignalsDevToolsController].
  BlocSignalsDevToolsController({
    required this.callExtensionRpc,
    this.debounceDuration = const Duration(milliseconds: 100),
    int maxHistory = 200,
  }) : _maxHistory = maxHistory;

  /// The RPC caller used to invoke VM service extensions.
  final DevToolsExtensionRpcCaller callExtensionRpc;

  /// Duration to coalesce rapid `onCreate` events before fetching instances.
  final Duration debounceDuration;

  final int _maxHistory;

  List<Map<String, dynamic>> _instances = [];

  /// The active container instances currently known to the inspector.
  List<Map<String, dynamic>> get instances => List.unmodifiable(_instances);

  final List<Map<String, dynamic>> _history = [];

  /// The unified chronological timeline of transitions, errors, and traces.
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  bool _isLoading = false;

  /// Whether a live data fetch or refresh is currently in progress.
  bool get isLoading => _isLoading;

  String? _errorMessage;

  /// An optional error banner message if RPC calls or connection fail.
  String? get errorMessage => _errorMessage;

  StreamSubscription<vm.Event>? _subscription;
  Timer? _debounceTimer;
  bool _isFetching = false;

  /// Attaches a stream of [vm.Event] (typically from
  /// `vm_service.onExtensionEvent`).
  void attachEventStream(Stream<vm.Event> stream) {
    unawaited(_subscription?.cancel());
    _subscription = stream.listen(handleEvent);
  }

  /// Processes an incoming [vm.Event] from the VM service.
  void handleEvent(vm.Event event) {
    final kind = event.extensionKind;
    if (kind == null || !kind.startsWith('bloc_signal.')) return;

    final rawData = event.extensionData?.data;
    final data = rawData != null
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};
    final id = data['hashCode'] as int?;

    if (kind == 'bloc_signal.onCreate') {
      _scheduleDebouncedFetch();
    } else if (kind == 'bloc_signal.onClose') {
      _handleClose(id);
    } else if (kind == 'bloc_signal.onTransition') {
      _handleTransition(id, data);
    } else if (kind == 'bloc_signal.onChange') {
      _handleChange(id, data);
    } else if (kind == 'bloc_signal.onError') {
      _handleError(id, data);
    } else if (kind == 'bloc_signal.onTelemetry') {
      _handleTelemetry(id, data);
    }
  }

  void _scheduleDebouncedFetch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      unawaited(fetchInstances());
    });
  }

  /// Fetches all active containers from `ext.bloc_signal.getInstances`.
  Future<void> fetchInstances() async {
    if (_isFetching) return;
    _isFetching = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final json = await callExtensionRpc('ext.bloc_signal.getInstances');
      final rawInstances = json['instances'] as List<dynamic>?;
      _instances = rawInstances?.cast<Map<String, dynamic>>().toList() ?? [];
      _isLoading = false;
      notifyListeners();
    } on Object catch (e) {
      _isLoading = false;
      _errorMessage =
          'Could not fetch containers. Ensure DevToolsBlocSignalObserver is '
          'registered: $e';
      notifyListeners();
    } finally {
      _isFetching = false;
    }
  }

  void _handleClose(int? id) {
    if (id == null) return;
    final idx = _instances.indexWhere((i) => i['hashCode'] == id);
    if (idx != -1) {
      _instances = List<Map<String, dynamic>>.from(_instances);
      _instances[idx] = {
        ..._instances[idx],
        'isClosed': true,
      };
      notifyListeners();
    }
  }

  void _handleTransition(int? id, Map<String, dynamic> data) {
    final transitionEntry = <String, dynamic>{
      'hashCode': id,
      'type': 'transition',
      'timestamp': data['timestamp'] != null
          ? DateTime.fromMicrosecondsSinceEpoch(
              (data['timestamp'] as num).toInt(),
            ).toIso8601String()
          : DateTime.now().toIso8601String(),
      'data': <String, dynamic>{
        'event': data['event'],
        'currentState': data['currentState'],
        'nextState': data['nextState'],
      },
    };

    _addHistoryEntry(transitionEntry);

    if (id != null) {
      final idx = _instances.indexWhere((i) => i['hashCode'] == id);
      if (idx != -1) {
        _instances = List<Map<String, dynamic>>.from(_instances);
        _instances[idx] = {
          ..._instances[idx],
          'stateValue': data['nextState']?.toString() ?? '',
        };
        notifyListeners();
      }
    }
  }

  void _handleChange(int? id, Map<String, dynamic> data) {
    if (id == null) return;
    final idx = _instances.indexWhere((i) => i['hashCode'] == id);
    if (idx != -1) {
      _instances = List<Map<String, dynamic>>.from(_instances);
      _instances[idx] = {
        ..._instances[idx],
        'stateValue': data['nextState']?.toString() ?? '',
      };
      notifyListeners();
    }
  }

  void _handleError(int? id, Map<String, dynamic> data) {
    final errorEntry = <String, dynamic>{
      'hashCode': id,
      'type': 'error',
      'timestamp': data['timestamp'] != null
          ? DateTime.fromMicrosecondsSinceEpoch(
              (data['timestamp'] as num).toInt(),
            ).toIso8601String()
          : DateTime.now().toIso8601String(),
      'data': <String, dynamic>{
        'error': data['error'],
        'stackTrace': data['stackTrace'],
      },
    };

    _addHistoryEntry(errorEntry);
  }

  void _handleTelemetry(int? id, Map<String, dynamic> data) {
    final telemetryEntry = <String, dynamic>{
      'hashCode': id,
      'type': 'telemetry',
      'timestamp': data['timestamp'] != null
          ? DateTime.fromMicrosecondsSinceEpoch(
              (data['timestamp'] as num).toInt(),
            ).toIso8601String()
          : DateTime.now().toIso8601String(),
      'data': <String, dynamic>{
        'name': data['name'],
        'event': data['event'],
        'metadata': data['metadata'],
      },
    };

    _addHistoryEntry(telemetryEntry);
  }

  void _trimHistory() {
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
  }

  void _addHistoryEntry(Map<String, dynamic> entry) {
    _history.insert(0, entry);
    _trimHistory();
    notifyListeners();
  }

  /// Fetches historical transitions for a specific container by its [hashCode].
  Future<void> fetchHistoryForInstance(int hashCode) async {
    try {
      final json = await callExtensionRpc(
        'ext.bloc_signal.getHistory',
        {'hashCode': '$hashCode'},
      );
      final historyList = json['history'] as List<dynamic>?;
      if (historyList != null) {
        final parsed = historyList.cast<Map<String, dynamic>>().toList();
        for (final entry in parsed) {
          final exists = _history.any(
            (e) =>
                e['timestamp'] == entry['timestamp'] &&
                e['hashCode'] == entry['hashCode'],
          );
          if (!exists) {
            _history.add(entry);
          }
        }
        _history.sort((a, b) {
          final tA = a['timestamp']?.toString() ?? '';
          final tB = b['timestamp']?.toString() ?? '';
          return tB.compareTo(tA);
        });
        _trimHistory();
        notifyListeners();
      }
    } on Object {
      // Historical buffer load failure falls back safely to live history
      // stream.
    }
  }

  /// Resets instance and history buffers.
  void reset() {
    _debounceTimer?.cancel();
    _instances = [];
    _history.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
