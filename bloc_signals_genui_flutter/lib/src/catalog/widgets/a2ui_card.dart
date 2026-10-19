import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Card` container.
///
/// Supports either a single `child` component ID or a `children` list.
///
/// ```dart
/// final widget = buildA2uiCard(context, componentContext);
/// ```
Widget buildA2uiCard(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final childIds = extractChildIds(props['children']);
  final elevation = asDouble(props['elevation'], 1);

  final Widget content;
  if (childId != null) {
    content = componentContext.buildChild(childId);
  } else if (childIds.isNotEmpty) {
    content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: componentContext.buildChildren(childIds),
    );
  } else {
    content = const SizedBox.shrink();
  }

  return Card(
    elevation: elevation,
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: content,
    ),
  );
}
