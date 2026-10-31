import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Row` container with layout alignment for Cupertino.
///
/// Supports both A2UI specification properties (`justify` and `align`) and
/// Flutter-style properties (`mainAxisAlignment` and `crossAxisAlignment`).
///
/// ```dart
/// final widget = buildCupertinoRow(context, componentContext);
/// ```
Widget buildCupertinoRow(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childIds = extractChildIds(props['children']);

  final justifyStr =
      (props['justify'] ?? props['mainAxisAlignment'])?.toString();
  final alignStr = (props['align'] ?? props['crossAxisAlignment'])?.toString();

  final mainAxisAlignment = switch (justifyStr) {
    'center' => MainAxisAlignment.center,
    'end' => MainAxisAlignment.end,
    'spaceBetween' => MainAxisAlignment.spaceBetween,
    'spaceAround' => MainAxisAlignment.spaceAround,
    'spaceEvenly' => MainAxisAlignment.spaceEvenly,
    _ => MainAxisAlignment.start,
  };

  final crossAxisAlignment = switch (alignStr) {
    'start' => CrossAxisAlignment.start,
    'end' => CrossAxisAlignment.end,
    'stretch' => CrossAxisAlignment.stretch,
    _ => CrossAxisAlignment.center,
  };

  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    children: componentContext.buildChildren(childIds),
  );
}
