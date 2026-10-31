import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Row` container with flexbox layout alignment.
///
/// Supports both A2UI specification properties (`justify` and `align`) and
/// framework properties (`mainAxisAlignment` and `crossAxisAlignment`).
///
/// ```dart
/// final component = buildA2uiRow(context, componentContext);
/// ```
Component buildA2uiRow(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childIds = extractChildIds(props['children']);

  final justifyStr =
      (props['justify'] ?? props['mainAxisAlignment'])?.toString();
  final alignStr = (props['align'] ?? props['crossAxisAlignment'])?.toString();

  final justifyContent = switch (justifyStr) {
    'center' => JustifyContent.center,
    'end' => JustifyContent.end,
    'spaceBetween' => JustifyContent.spaceBetween,
    'spaceAround' => JustifyContent.spaceAround,
    'spaceEvenly' => JustifyContent.spaceEvenly,
    _ => JustifyContent.start,
  };

  final alignItems = switch (alignStr) {
    'start' => AlignItems.start,
    'end' => AlignItems.end,
    'stretch' => AlignItems.stretch,
    _ => AlignItems.center,
  };

  return div(
    classes: 'a2ui-row',
    styles: Styles(
      display: Display.flex,
      flexDirection: FlexDirection.row,
      justifyContent: justifyContent,
      alignItems: alignItems,
    ),
    componentContext.buildChildren(childIds),
  );
}
