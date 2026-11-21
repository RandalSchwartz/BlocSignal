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
  bool _isDisposed = false;
  int _fetchGeneration = 0;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  static const int _maxDateTimeMicroseconds = 8640000000000000000;

  static String _parseTimestamp(dynamic rawTs) {
    if (rawTs is num && rawTs.isFinite) {
      final micros = rawTs.toInt();
      if (micros >= -_maxDateTimeMicroseconds &&
          micros <= _maxDateTimeMicroseconds) {
        return DateTime.fromMicrosecondsSinceEpoch(micros).toIso8601String();
      }
    }
    return DateTime.now().toIso8601String();
  }

  /// Attaches a stream of [vm.Event] (typically from
  /// `vm_service.onExtensionEvent`).
  void attachEventStream(Stream<vm.Event> stream) {
    if (_isDisposed) return;
    unawaited(_subscription?.cancel());
    _subscription = stream.listen(
      handleEvent,
      onError: (Object error, StackTrace stackTrace) {
        if (_isDisposed) return;
        _errorMessage = 'VM service event stream error: $error';
        _safeNotifyListeners();
      },
    );
  }

  /// Processes an incoming [vm.Event] from the VM service.
  void handleEvent(vm.Event event) {
    if (_isDisposed) return;
    final kind = event.extensionKind;
    if (kind == null || !kind.startsWith('bloc_signal.')) return;

    final Map<Object?, Object?>? rawData = event.extensionData?.data;
    final data = rawData != null
        ? <String, dynamic>{
            for (final entry in rawData.entries)
              if (entry.key is String) entry.key! as String: entry.value,
          }
        : const <String, dynamic>{};
    final rawId = data['hashCode'];
    final id = rawId is int ? rawId : null;

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
      if (_isDisposed) return;
      unawaited(fetchInstances());
    });
  }

  /// Fetches all active containers from `ext.bloc_signal.getInstances`.
  Future<void> fetchInstances() async {
    if (_isFetching || _isDisposed) return;
    final generation = _fetchGeneration;
    _isFetching = true;
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final json = await callExtensionRpc('ext.bloc_signal.getInstances');
      if (_isDisposed || generation != _fetchGeneration) return;
      final rawInstances = json['instances'];
      _instances = rawInstances is List
          ? rawInstances.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      // SCAR-ERR-02: Justified exception: DevTools controller RPC polling must
      // surface any RPC/wire failure in the UI error banner without crashing
      // the DevTools panel or wedging _isLoading.
    } on Object catch (e) {
      if (!_isDisposed && generation == _fetchGeneration) {
        _errorMessage =
            'Could not fetch containers. Ensure DevToolsBlocSignalObserver is '
            'registered: $e';
      }
    } finally {
      if (generation == _fetchGeneration) {
        _isLoading = false;
        _isFetching = false;
        _safeNotifyListeners();
      }
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
      _safeNotifyListeners();
    }
  }

  void _handleTransition(int? id, Map<String, dynamic> data) {
    final transitionEntry = <String, dynamic>{
      'hashCode': id,
      'type': 'transition',
      'timestamp': _parseTimestamp(data['timestamp']),
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
        _safeNotifyListeners();
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
      _safeNotifyListeners();
    }
  }

  void _handleError(int? id, Map<String, dynamic> data) {
    final errorEntry = <String, dynamic>{
      'hashCode': id,
      'type': 'error',
      'timestamp': _parseTimestamp(data['timestamp']),
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
      'timestamp': _parseTimestamp(data['timestamp']),
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
    _safeNotifyListeners();
  }

  /// Fetches historical transitions for a specific container by its [hashCode].
  Future<void> fetchHistoryForInstance(int hashCode) async {
    if (_isDisposed) return;
    final generation = _fetchGeneration;
    try {
      final json = await callExtensionRpc(
        'ext.bloc_signal.getHistory',
        {'hashCode': '$hashCode'},
      );
      if (_isDisposed || generation != _fetchGeneration) return;
      final historyList = json['history'];
      if (historyList is List) {
        final parsed = historyList.whereType<Map<String, dynamic>>().toList();
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
        _safeNotifyListeners();
      }
      // SCAR-ERR-02: Justified exception: Historical buffer load failure
      // falls back safely to the live history stream.
    } on Object {
      // Historical buffer load failure falls back safely to live history
      // stream.
    }
  }

  /// Resets instance and history buffers.
  void reset() {
    if (_isDisposed) return;
    _fetchGeneration++;
    _debounceTimer?.cancel();
    _instances = [];
    _history.clear();
    _isFetching = false;
    _isLoading = false;
    _errorMessage = null;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
