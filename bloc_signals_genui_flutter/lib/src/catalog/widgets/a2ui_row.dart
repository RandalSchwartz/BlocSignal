import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Row` container with layout alignment.
Widget buildA2uiRow(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final rawChildren = props['children'];
  final childIds = <String>[];

  if (rawChildren is List) {
    for (final child in rawChildren) {
      if (child is ChildNode) {
        childIds.add(child.id);
      } else if (child is Map && child.containsKey('id')) {
        childIds.add(child['id'].toString());
      } else if (child != null) {
        childIds.add(child.toString());
      }
    }
  }

  final mainAxisAlignmentStr = props['mainAxisAlignment']?.toString();
  final crossAxisAlignmentStr = props['crossAxisAlignment']?.toString();

  var mainAxisAlignment = MainAxisAlignment.start;
  switch (mainAxisAlignmentStr) {
    case 'center':
      mainAxisAlignment = MainAxisAlignment.center;
    case 'end':
      mainAxisAlignment = MainAxisAlignment.end;
    case 'spaceBetween':
      mainAxisAlignment = MainAxisAlignment.spaceBetween;
    case 'spaceAround':
      mainAxisAlignment = MainAxisAlignment.spaceAround;
    case 'spaceEvenly':
      mainAxisAlignment = MainAxisAlignment.spaceEvenly;
    default:
      mainAxisAlignment = MainAxisAlignment.start;
  }

  var crossAxisAlignment = CrossAxisAlignment.center;
  switch (crossAxisAlignmentStr) {
    case 'start':
      crossAxisAlignment = CrossAxisAlignment.start;
    case 'end':
      crossAxisAlignment = CrossAxisAlignment.end;
    case 'stretch':
      crossAxisAlignment = CrossAxisAlignment.stretch;
    default:
      crossAxisAlignment = CrossAxisAlignment.center;
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: mainAxisAlignment,
    crossAxisAlignment: crossAxisAlignment,
    children: componentContext.buildChildren(childIds),
  );
}
