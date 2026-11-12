import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Button` component.
///
/// Automatically disables the button (`onPressed: null`) when
/// [A2uiComponentContext.isValid] is `false` (for example due to a failing
/// `CheckRule`) or when `props['enabled']` evaluates to `false`.
///
/// ```dart
/// final widget = buildA2uiButton(context, componentContext);
/// ```
Widget buildA2uiButton(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final variant = asString(props['variant'], 'primary');

  final isEnabled =
      componentContext.isValid && asBool(props['enabled'], defaultValue: true);

  final child = childId != null
      ? componentContext.buildChild(childId)
      : const Text('Action');

  final onPressed = isEnabled ? componentContext.triggerAction : null;

  if (variant == 'borderless') {
    return TextButton(
      onPressed: onPressed,
      child: child,
    );
  }

  return ElevatedButton(
    onPressed: onPressed,
    child: child,
  );
}
