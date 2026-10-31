import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `List` component as a scrollable horizontal or vertical
/// layout styled for Cupertino.
///
/// Supports `children`, `direction` (or `axis`: `'vertical'` default,
/// `'horizontal'`), and `align` (`'start'`, `'center'`, `'end'`, `'stretch'`).
///
/// ```dart
/// final widget = buildCupertinoList(context, componentContext);
/// ```
Widget buildCupertinoList(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childIds = extractChildIds(props['children']);
  final directionStr = asString(
    props['direction'] ?? props['axis'],
    'vertical',
  );
  final alignStr = asString(
    props['align'] ?? props['crossAxisAlignment'],
    'stretch',
  );

  final crossAxisAlignment = switch (alignStr) {
    'start' => CrossAxisAlignment.start,
    'center' => CrossAxisAlignment.center,
    'end' => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.stretch,
  };

  final children = componentContext.buildChildren(childIds);

  if (directionStr == 'horizontal') {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment == CrossAxisAlignment.stretch
            ? CrossAxisAlignment.center
            : crossAxisAlignment,
        children: children,
      ),
    );
  }

  return SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: children,
    ),
  );
}
