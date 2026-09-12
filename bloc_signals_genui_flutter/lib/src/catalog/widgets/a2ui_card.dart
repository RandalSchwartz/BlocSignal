import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Card` container.
Widget buildA2uiCard(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final rawChild = props['child'];
  final childId = switch (rawChild) {
    final ChildNode node => node.id,
    final Map<String, dynamic> map => map['id']?.toString(),
    final Object obj => obj.toString(),
    null => null,
  };

  final elevation = (props['elevation'] as num?)?.toDouble() ?? 1.0;

  return Card(
    elevation: elevation,
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: childId != null
          ? componentContext.buildChild(childId)
          : const SizedBox.shrink(),
    ),
  );
}
