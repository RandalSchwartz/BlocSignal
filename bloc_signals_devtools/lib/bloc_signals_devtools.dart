import 'package:bloc_signals_devtools/src/instance_tree_view.dart';
import 'package:bloc_signals_devtools/src/leak_detector_badge.dart';
import 'package:bloc_signals_devtools/src/state_diff_inspector.dart';
import 'package:bloc_signals_devtools/src/timeline_trace_panel.dart';
import 'package:flutter/material.dart';

export 'src/devtools_controller.dart';
export 'src/instance_tree_view.dart';
export 'src/leak_detector_badge.dart';
export 'src/state_diff_inspector.dart';
export 'src/timeline_trace_panel.dart';

/// The root DevTools extension UI for inspecting `BlocSignal` containers.
///
/// Example:
/// ```dart
/// BlocSignalsDevToolsExtension(
///   instances: [
///     {
///       'hashCode': 12345,
///       'type': 'CounterCubit',
///       'stateValue': '0',
///       'isClosed': false,
///     },
///   ],
///   history: [
///     {
///       'type': 'transition',
///       'timestamp': '2026-07-30T15:00:00Z',
///       'data': {'event': 'Increment()', 'nextState': '1'},
///     },
///   ],
/// )
/// ```
class BlocSignalsDevToolsExtension extends StatefulWidget {
  /// Creates a [BlocSignalsDevToolsExtension].
  const BlocSignalsDevToolsExtension({
    super.key,
    this.instances = const [],
    this.history = const [],
    this.isLoading = false,
    this.errorMessage,
    this.onRefresh,
    this.onSelectInstance,
  });

  /// Injected list of instance maps.
  final List<Map<String, dynamic>> instances;

  /// Injected transition history list.
  final List<Map<String, dynamic>> history;

  /// Whether a data refresh or fetch is in progress.
  final bool isLoading;

  /// An optional error message to display in an alert banner.
  final String? errorMessage;

  /// Optional callback invoked when the user taps the refresh action button.
  final VoidCallback? onRefresh;

  /// Optional callback invoked when a container instance is selected.
  final ValueChanged<Map<String, dynamic>>? onSelectInstance;

  @override
  State<BlocSignalsDevToolsExtension> createState() =>
      _BlocSignalsDevToolsExtensionState();
}

class _BlocSignalsDevToolsExtensionState
    extends State<BlocSignalsDevToolsExtension> {
  Map<String, dynamic>? _selectedInstance;
  Map<String, dynamic>? _selectedHistoryEntry;

  @override
  Widget build(BuildContext context) {
    final instances = widget.instances;
    final selectedHashCode = _selectedInstance?['hashCode'] as int?;

    // Filter history entries for selected container instance
    final filteredHistory = widget.history.where((entry) {
      if (selectedHashCode == null) return true;
      final instanceId = entry['hashCode'] ?? entry['instanceHashCode'];
      return instanceId == null || instanceId == selectedHashCode;
    }).toList();

    // Derive state diff values from selected history entry or selected instance
    final historyData =
        (_selectedHistoryEntry?['data'] as Map<String, dynamic>?) ?? {};
    final currentState = historyData['currentState']?.toString() ??
        historyData['prevState']?.toString() ??
        historyData['event']?.toString() ??
        'Initial State';
    final nextState = historyData['nextState']?.toString() ??
        _selectedInstance?['stateValue']?.toString() ??
        '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlocSignal DevTools Inspector'),
        actions: [
          if (widget.onRefresh != null) ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Containers',
              onPressed: widget.isLoading ? null : widget.onRefresh,
            ),
            const SizedBox(width: 8),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LeakDetectorBadge(instances: instances),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (widget.errorMessage != null)
            MaterialBanner(
              content: Text(widget.errorMessage!),
              backgroundColor: Colors.amber.shade50,
              actions: [
                if (widget.onRefresh != null)
                  TextButton(
                    onPressed: widget.onRefresh,
                    child: const Text('RETRY'),
                  ),
              ],
            ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: InstanceTreeView(
                    instances: instances,
                    selectedHashCode: selectedHashCode,
                    onSelectInstance: (item) {
                      setState(() {
                        _selectedInstance = item;
                        _selectedHistoryEntry = null;
                      });
                      widget.onSelectInstance?.call(item);
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedInstance == null
                      ? Center(
                          child: Text(
                            instances.isEmpty && !widget.isLoading
                                ? 'No active BlocSignal containers detected.\n'
                                    'Ensure DevToolsBlocSignalObserver '
                                    'is registered.'
                                : 'Select a container to inspect details.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: StateDiffInspector(
                                currentState: currentState,
                                nextState: nextState,
                              ),
                            ),
                            Expanded(
                              child: TimelineTracePanel(
                                history: filteredHistory,
                                selectedEntry: _selectedHistoryEntry,
                                onSelectEntry: (entry) {
                                  setState(() {
                                    _selectedHistoryEntry = entry;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
