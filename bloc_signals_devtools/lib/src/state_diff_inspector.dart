import 'package:flutter/material.dart';

/// An interactive object diff inspector comparing previous and next state values.
class StateDiffInspector extends StatelessWidget {
  /// Creates a [StateDiffInspector].
  const StateDiffInspector({
    required this.currentState,
    required this.nextState,
    super.key,
  });

  /// Current/previous state string representation.
  final String currentState;

  /// Next state string representation.
  final String nextState;

  @override
  Widget build(BuildContext context) {
    final isEqual = currentState == nextState;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.difference_outlined, size: 18),
              const SizedBox(width: 8),
              const Text(
                'State Transition Diff',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  isEqual ? 'Unchanged' : 'Mutated',
                  style: TextStyle(
                    fontSize: 10,
                    color: isEqual ? Colors.grey : Colors.green.shade900,
                  ),
                ),
                backgroundColor:
                    isEqual ? Colors.grey.shade200 : Colors.green.shade100,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _DiffBox(
                  title: 'Current State (-)',
                  content: currentState,
                  color: Colors.red.shade50,
                  textColor: Colors.red.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DiffBox(
                  title: 'Next State (+)',
                  content: nextState,
                  color: Colors.green.shade50,
                  textColor: Colors.green.shade900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiffBox extends StatelessWidget {
  const _DiffBox({
    required this.title,
    required this.content,
    required this.color,
    required this.textColor,
  });

  final String title;
  final String content;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
