import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Card` container using iOS inset-grouped styling.
///
/// Supports either a single `child` component ID or a `children` list.
///
/// ```dart
/// final widget = buildCupertinoCard(context, componentContext);
/// ```
Widget buildCupertinoCard(
  BuildContext context,
  A2uiComponentContext componentContext, {
  CupertinoCatalogTokens? tokens,
}) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final childIds = extractChildIds(props['children']);

  final Widget content;
  if (childId != null) {
    content = componentContext.buildChild(childId);
  } else if (childIds.isNotEmpty) {
    content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: componentContext.buildChildren(childIds),
    );
  } else {
    content = const SizedBox.shrink();
  }

  final resolvedCardColor = tokens?.cardColor ??
      CupertinoDynamicColor.resolve(
        CupertinoColors.secondarySystemGroupedBackground,
        context,
      );
  final resolvedBorderRadius =
      tokens?.borderRadius ?? const BorderRadius.all(Radius.circular(10));

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: resolvedCardColor,
      borderRadius: resolvedBorderRadius,
    ),
    padding: const EdgeInsets.all(12),
    child: content,
  );
}
