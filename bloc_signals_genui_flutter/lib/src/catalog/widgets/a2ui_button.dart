import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Button` component.
Widget buildA2uiButton(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final rawChild = props['child'];
  final childId = switch (rawChild) {
    final ChildNode node => node.id,
    final Map<String, dynamic> map => map['id']?.toString(),
    final Object obj => obj.toString(),
    null => null,
  };

  final variant = props['variant']?.toString() ?? 'primary';
  final rawAction = props['action'];
  final modelAction = componentContext.component.properties['action'];

  final child = childId != null
      ? componentContext.buildChild(childId)
      : const Text('Action');

  void onPressed() {
    var actionName = 'submit';
    var actionContext = const <String, dynamic>{};

    final sourceAction =
        rawAction is Map || rawAction is String ? rawAction : modelAction;

    if (sourceAction is Map) {
      if (sourceAction['event'] is Map) {
        actionName =
            (sourceAction['event'] as Map)['name']?.toString() ?? 'submit';
      } else if (sourceAction['name'] != null) {
        actionName = sourceAction['name'].toString();
      }
      if (sourceAction['context'] is Map) {
        actionContext =
            Map<String, dynamic>.from(sourceAction['context'] as Map);
      }
    } else if (sourceAction is String) {
      actionName = sourceAction;
    }

    componentContext.dispatchAction(actionName, context: actionContext);
  }

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
