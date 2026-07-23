import 'package:flutter/material.dart';

/// An alert badge indicating active container count and warning against unclosed memory leaks.
class LeakDetectorBadge extends StatelessWidget {
  /// Creates a [LeakDetectorBadge].
  const LeakDetectorBadge({
    required this.instances,
    super.key,
  });

  /// List of raw instance maps from `ext.bloc_signal.getInstances`.
  final List<Map<String, dynamic>> instances;

  @override
  Widget build(BuildContext context) {
    final activeCount =
        instances.where((item) => item['isClosed'] != true).length;
    final closedCount =
        instances.where((item) => item['isClosed'] == true).length;
    final hasHighRetain = activeCount > 20;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasHighRetain ? Colors.amber.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasHighRetain ? Colors.amber.shade700 : Colors.blue.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasHighRetain
                ? Icons.warning_amber_rounded
                : Icons.memory_outlined,
            size: 16,
            color:
                hasHighRetain ? Colors.amber.shade900 : Colors.blue.shade900,
          ),
          const SizedBox(width: 6),
          Text(
            'Active: $activeCount | Closed: $closedCount',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color:
                  hasHighRetain ? Colors.amber.shade900 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
