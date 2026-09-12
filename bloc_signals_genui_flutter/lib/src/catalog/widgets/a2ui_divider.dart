import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Divider` component.
Widget buildA2uiDivider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final height = (props['height'] as num?)?.toDouble() ?? 16.0;
  final thickness = (props['thickness'] as num?)?.toDouble() ?? 1.0;

  return Divider(
    height: height,
    thickness: thickness,
  );
}
