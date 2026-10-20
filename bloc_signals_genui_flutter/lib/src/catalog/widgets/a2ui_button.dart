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
  final rawAction = props['action'];
  final modelAction = componentContext.component.properties['action'];

  final isEnabled =
      componentContext.isValid && asBool(props['enabled'], defaultValue: true);

  final child = childId != null
      ? componentContext.buildChild(childId)
      : const Text('Action');

  void handlePressed() {
    var actionName = 'submit';
    var actionContext = const <String, dynamic>{};

    final sourceAction =
        rawAction is Map || rawAction is String ? rawAction : modelAction;

    if (sourceAction is Map) {
      final eventMap =
          sourceAction['event'] is Map ? sourceAction['event'] as Map : null;
      if (eventMap != null) {
        actionName = eventMap['name']?.toString() ?? 'submit';
        if (eventMap['context'] is Map) {
          actionContext = Map<String, dynamic>.from(eventMap['context'] as Map);
        }
      } else if (sourceAction['name'] != null) {
        actionName = sourceAction['name'].toString();
      }

      if (actionContext.isEmpty && sourceAction['context'] is Map) {
        actionContext =
            Map<String, dynamic>.from(sourceAction['context'] as Map);
      }
    } else if (sourceAction is String) {
      actionName = sourceAction;
    }

    componentContext.dispatchAction(actionName, context: actionContext);
  }

  final onPressed = isEnabled ? handlePressed : null;

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
