import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Text` component with typography hierarchy.
Widget buildA2uiText(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final text = props['text']?.toString() ?? '';
  final variant = props['variant']?.toString() ?? 'body';

  final textTheme = Theme.of(context).textTheme;
  var style = textTheme.bodyMedium;

  switch (variant) {
    case 'h1':
      style = textTheme.headlineLarge;
    case 'h2':
      style = textTheme.headlineMedium;
    case 'h3':
      style = textTheme.headlineSmall;
    case 'title':
      style = textTheme.titleMedium;
    case 'caption':
      style = textTheme.bodySmall;
    case 'body':
      style = textTheme.bodyMedium;
    default:
      style = textTheme.bodyMedium;
  }

  return Text(
    text,
    style: style,
  );
}
