import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Text` component using Cupertino typography hierarchy.
///
/// Supports `variant` (`h1`, `h2`, `h3`, `h4`, `h5`, `title`, `caption`, and
/// `body`) as well as the `style` property fallback.
///
/// ```dart
/// final widget = buildCupertinoText(context, componentContext);
/// ```
Widget buildCupertinoText(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final text = asString(props['text']);
  final variant = asString(props['variant'] ?? props['style'], 'body');

  final textTheme = CupertinoTheme.of(context).textTheme;
  final baseTextStyle = textTheme.textStyle;

  final style = switch (variant) {
    'h1' => textTheme.navLargeTitleTextStyle,
    'h2' => baseTextStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
    'h3' => baseTextStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
    'h4' => baseTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
    'h5' || 'title' => textTheme.navActionTextStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    'caption' => textTheme.tabLabelTextStyle,
    _ => baseTextStyle,
  };

  return Text(
    text,
    style: style,
  );
}
