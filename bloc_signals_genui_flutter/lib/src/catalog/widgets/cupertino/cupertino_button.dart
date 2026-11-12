import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Button` component using Cupertino widgets.
///
/// Automatically disables the button (`onPressed: null`) when
/// [A2uiComponentContext.isValid] is `false` (for example due to a failing
/// `CheckRule`) or when `props['enabled']` evaluates to `false`.
///
/// ```dart
/// final widget = buildCupertinoButton(context, componentContext);
/// ```
Widget buildCupertinoButton(
  BuildContext context,
  A2uiComponentContext componentContext, {
  CupertinoCatalogTokens? tokens,
}) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final variant = asString(props['variant'], 'primary');

  final isEnabled =
      componentContext.isValid && asBool(props['enabled'], defaultValue: true);

  final child = childId != null
      ? componentContext.buildChild(childId)
      : const Text('Action');

  final onPressed = isEnabled ? componentContext.triggerAction : null;
  final borderRadius =
      tokens?.borderRadius ?? const BorderRadius.all(Radius.circular(8));

  if (variant == 'borderless') {
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: borderRadius,
      child: child,
    );
  }

  return CupertinoButton.filled(
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    borderRadius: borderRadius,
    child: child,
  );
}
