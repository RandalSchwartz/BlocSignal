import 'package:bloc_signals_devtools/src/instance_tree_view.dart';
import 'package:bloc_signals_devtools/src/leak_detector_badge.dart';
import 'package:bloc_signals_devtools/src/state_diff_inspector.dart';
import 'package:bloc_signals_devtools/src/timeline_trace_panel.dart';
import 'package:flutter/material.dart';

export 'src/instance_tree_view.dart';
export 'src/leak_detector_badge.dart';
export 'src/state_diff_inspector.dart';
export 'src/timeline_trace_panel.dart';

/// The root DevTools extension UI for inspecting `BlocSignal` containers.
class BlocSignalsDevToolsExtension extends StatefulWidget {
  /// Creates a [BlocSignalsDevToolsExtension].
  const BlocSignalsDevToolsExtension({
    super.key,
    this.instances = const [],
    this.history = const [],
  });

  /// Initial or injected list of instance maps.
  final List<Map<String, dynamic>> instances;

  /// Initial or injected transition history list.
  final List<Map<String, dynamic>> history;

  @override
  State<BlocSignalsDevToolsExtension> createState() =>
      _BlocSignalsDevToolsExtensionState();
}

class _BlocSignalsDevToolsExtensionState
    extends State<BlocSignalsDevToolsExtension> {
  Map<String, dynamic>? _selectedInstance;

  @override
  Widget build(BuildContext context) {
    final instances = widget.instances;
    final selectedHashCode = _selectedInstance?['hashCode'] as int?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlocSignal DevTools Inspector'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LeakDetectorBadge(instances: instances),
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: InstanceTreeView(
              instances: instances,
              selectedHashCode: selectedHashCode,
              onSelectInstance: (item) {
                setState(() {
                  _selectedInstance = item;
                });
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedInstance == null
                ? const Center(
                    child: Text('Select a container to inspect details.'),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: StateDiffInspector(
                          currentState:
                              _selectedInstance!['stateValue']?.toString() ??
                                  '',
                          nextState:
                              _selectedInstance!['stateValue']?.toString() ??
                                  '',
                        ),
                      ),
                      Expanded(
                        child: TimelineTracePanel(history: widget.history),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
