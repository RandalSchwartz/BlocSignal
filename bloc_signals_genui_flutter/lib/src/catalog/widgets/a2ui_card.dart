import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Card` container.
Widget buildA2uiCard(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final elevation = asDouble(props['elevation'], 1);

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
