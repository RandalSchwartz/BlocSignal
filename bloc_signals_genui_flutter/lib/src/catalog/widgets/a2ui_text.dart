import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Text` component with typography hierarchy.
///
/// Supports `variant` (`h1`, `h2`, `h3`, `h4`, `h5`, `title`, `caption`, and
/// `body`) as well as the `style` property fallback.
///
/// ```dart
/// final widget = buildA2uiText(context, componentContext);
/// ```
Widget buildA2uiText(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final text = asString(props['text']);
  final variant = asString(props['variant'] ?? props['style'], 'body');

  final textTheme = Theme.of(context).textTheme;
  final style = switch (variant) {
    'h1' => textTheme.headlineLarge,
    'h2' => textTheme.headlineMedium,
    'h3' => textTheme.headlineSmall,
    'h4' => textTheme.titleLarge,
    'h5' || 'title' => textTheme.titleMedium,
    'caption' => textTheme.bodySmall,
    _ => textTheme.bodyMedium,
  };

  return Text(
    text,
    style: style,
  );
}
