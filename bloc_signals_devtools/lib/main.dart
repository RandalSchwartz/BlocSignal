import 'dart:async';

import 'package:bloc_signals_devtools/bloc_signals_devtools.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BlocSignalsDevToolsExtensionApp());
}

/// The root application widget for the `BlocSignal` DevTools extension web app.
class BlocSignalsDevToolsExtensionApp extends StatelessWidget {
  /// Creates a [BlocSignalsDevToolsExtensionApp].
  const BlocSignalsDevToolsExtensionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: _LiveBlocSignalsDevToolsExtension(),
    );
  }
}

class _LiveBlocSignalsDevToolsExtension extends StatefulWidget {
  const _LiveBlocSignalsDevToolsExtension();

  @override
  State<_LiveBlocSignalsDevToolsExtension> createState() =>
      _LiveBlocSignalsDevToolsExtensionState();
}

class _LiveBlocSignalsDevToolsExtensionState
    extends State<_LiveBlocSignalsDevToolsExtension> {
  late final BlocSignalsDevToolsController _controller;
  bool _listenerAttached = false;

  ServiceManager? get _maybeServiceManager {
    try {
      return serviceManager;
    } on Object {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = BlocSignalsDevToolsController(
      callExtensionRpc: (method, [args]) async {
        final sm = _maybeServiceManager;
        if (sm == null) throw StateError('ServiceManager not available');
        final response = await sm.callServiceExtensionOnMainIsolate(
          method,
          args: args,
        );
        return response.json ?? const {};
      },
    );
    _initLiveConnection();
  }

  void _initLiveConnection() {
    final sm = _maybeServiceManager;
    if (sm == null) return;

    if (!_listenerAttached) {
      sm.connectedState.addListener(_onConnectionChanged);
      _listenerAttached = true;
    }

    if (sm.connectedState.value.connected) {
      final service = sm.service;
      if (service != null) {
        _controller.attachEventStream(service.onExtensionEvent);
      }
      unawaited(_controller.fetchInstances());
    }
  }

  void _onConnectionChanged() {
    final sm = _maybeServiceManager;
    if (sm == null || !mounted) return;

    if (sm.connectedState.value.connected) {
      final service = sm.service;
      if (service != null) {
        _controller.attachEventStream(service.onExtensionEvent);
      }
      unawaited(_controller.fetchInstances());
    } else {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    if (_listenerAttached) {
      _maybeServiceManager?.connectedState.removeListener(_onConnectionChanged);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return BlocSignalsDevToolsExtension(
          instances: _controller.instances,
          history: _controller.history,
          isLoading: _controller.isLoading,
          errorMessage: _controller.errorMessage,
          onRefresh: _controller.fetchInstances,
          onSelectInstance: (item) {
            final hashCode = item['hashCode'] as int?;
            if (hashCode != null) {
              unawaited(_controller.fetchHistoryForInstance(hashCode));
            }
          },
        );
      },
    );
  }
}
