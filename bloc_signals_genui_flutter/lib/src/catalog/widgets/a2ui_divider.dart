import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Divider` component.
Widget buildA2uiDivider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final height = asDouble(props['height'], 16);
  final thickness = asDouble(props['thickness'], 1);

  return Divider(
    height: height,
    thickness: thickness,
  );
}
