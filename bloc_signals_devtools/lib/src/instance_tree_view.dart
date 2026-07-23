import 'package:flutter/material.dart';

/// A widget that renders a searchable list of active container instances.
class InstanceTreeView extends StatefulWidget {
  /// Creates an [InstanceTreeView].
  const InstanceTreeView({
    required this.instances,
    required this.onSelectInstance,
    super.key,
    this.selectedHashCode,
  });

  /// List of raw instance maps from `ext.bloc_signal.getInstances`.
  final List<Map<String, dynamic>> instances;

  /// Currently selected container instance ID.
  final int? selectedHashCode;

  /// Callback when a container instance row is selected.
  final ValueChanged<Map<String, dynamic>> onSelectInstance;

  @override
  State<InstanceTreeView> createState() => _InstanceTreeViewState();
}

class _InstanceTreeViewState extends State<InstanceTreeView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.instances.where((item) {
      final type = item['type']?.toString().toLowerCase() ?? '';
      final hashCode = item['hashCode']?.toString().toLowerCase() ?? '';
      final state = item['stateValue']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return type.contains(query) ||
          hashCode.contains(query) ||
          state.contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            key: const Key('instance_search_field'),
            decoration: const InputDecoration(
              hintText: 'Search container by type, ID, or state...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No matching containers found.'),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final hashCode = item['hashCode'] as int?;
                    final isSelected = hashCode == widget.selectedHashCode;
                    final isClosed = item['isClosed'] == true;

                    return ListTile(
                      key: Key('instance_tile_$hashCode'),
                      selected: isSelected,
                      selectedTileColor:
                          Theme.of(context).primaryColor.withAlpha(25),
                      leading: Icon(
                        isClosed
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline,
                        color: isClosed ? Colors.grey : Colors.green,
                      ),
                      title: Text(
                        item['type']?.toString() ?? 'BlocSignalBase',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'ID: $hashCode | State: ${item['stateValue']}',
                      ),
                      onTap: () => widget.onSelectInstance(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
