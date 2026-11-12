import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `List` component as a scrollable horizontal or vertical
/// flex container.
///
/// Supports `children`, `direction` (or `axis`: `'vertical'` default,
/// `'horizontal'`), and `align` (`'start'`, `'center'`, `'end'`, `'stretch'`).
///
/// ```dart
/// final component = buildA2uiList(context, componentContext);
/// ```
Component buildA2uiList(
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

  final isHorizontal = directionStr == 'horizontal';
  final alignItems = switch (alignStr) {
    'start' => AlignItems.start,
    'center' => AlignItems.center,
    'end' => AlignItems.end,
    _ => AlignItems.stretch,
  };

  return div(
    classes: isHorizontal
        ? 'a2ui-list a2ui-list-horizontal'
        : 'a2ui-list a2ui-list-vertical',
    styles: Styles(
      display: Display.flex,
      flexDirection: isHorizontal ? FlexDirection.row : FlexDirection.column,
      alignItems: alignItems,
      overflow: isHorizontal
          ? const Overflow.only(x: Overflow.auto)
          : const Overflow.only(y: Overflow.auto),
    ),
    componentContext.buildChildren(childIds),
  );
}
