import 'package:flutter/material.dart';

/// A widget rendering a chronological timeline mapping events to state
/// transitions.
class TimelineTracePanel extends StatelessWidget {
  /// Creates a [TimelineTracePanel].
  const TimelineTracePanel({
    required this.history,
    super.key,
  });

  /// Raw history entries list from `ext.bloc_signal.getHistory`.
  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Text('No transition history recorded for this container.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = history[index];
        final type = entry['type']?.toString() ?? 'transition';
        final timestamp = entry['timestamp']?.toString() ?? '';
        final data = (entry['data'] as Map<String, dynamic>?) ?? {};
        final isError = type == 'error';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.swap_horiz,
                color: isError ? Colors.red : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isError ? Colors.red : Colors.blue,
                          ),
                        ),
                        Text(
                          timestamp,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isError) ...[
                      Text(
                        'Error: ${data['error']}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ] else ...[
                      if (data['event'] != null)
                        Text(
                          'Event: ${data['event']}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      Text(
                        'Next State: ${data['nextState']}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
