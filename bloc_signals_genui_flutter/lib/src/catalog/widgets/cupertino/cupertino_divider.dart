import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Divider` component using Cupertino hairline separator
/// styling.
///
/// Supports `axis` (`horizontal` or `vertical`), `height`, `width`, and
/// `thickness`.
///
/// ```dart
/// final widget = buildCupertinoDivider(context, componentContext);
/// ```
Widget buildCupertinoDivider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final axis = asString(props['axis'], 'horizontal');
  final thickness = asDouble(props['thickness'], 1);
  final separatorColor = CupertinoDynamicColor.resolve(
    CupertinoColors.separator,
    context,
  );

  if (axis == 'vertical') {
    final width = asDouble(props['width'] ?? props['height'], 16);
    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          width: thickness,
          color: separatorColor,
        ),
      ),
    );
  }

  final height = asDouble(props['height'], 16);
  return SizedBox(
    height: height,
    child: Center(
      child: Container(
        height: thickness,
        color: separatorColor,
      ),
    ),
  );
}
