import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
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
  final thickness = asBoundedDouble(
    props['thickness'],
    min: 0,
    max: 64,
    defaultValue: 1,
  );

  if (axis == 'vertical') {
    final width = asBoundedDouble(
      props['width'] ?? props['height'],
      min: 0,
      max: 512,
      defaultValue: 16,
    );
    return VerticalDivider(
      width: width,
      thickness: thickness,
    );
  }

  final height = asBoundedDouble(
    props['height'],
    min: 0,
    max: 512,
    defaultValue: 16,
  );
  return Divider(
    height: height,
    thickness: thickness,
  );
}
