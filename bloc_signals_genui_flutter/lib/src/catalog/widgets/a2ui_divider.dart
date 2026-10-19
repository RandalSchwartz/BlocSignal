import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Divider` component.
///
/// Supports `axis` (`horizontal` or `vertical`), `height`, `width`, and
/// `thickness`.
///
/// ```dart
/// final widget = buildA2uiDivider(context, componentContext);
/// ```
Widget buildA2uiDivider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final axis = asString(props['axis'], 'horizontal');
  final thickness = asDouble(props['thickness'], 1);

  if (axis == 'vertical') {
    final width = asDouble(props['width'] ?? props['height'], 16);
    return VerticalDivider(
      width: width,
      thickness: thickness,
    );
  }

  final height = asDouble(props['height'], 16);
  return Divider(
    height: height,
    thickness: thickness,
  );
}
