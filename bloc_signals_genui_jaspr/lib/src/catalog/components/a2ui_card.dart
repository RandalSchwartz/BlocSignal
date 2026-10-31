import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Card` container in the DOM.
///
/// Supports either a single `child` component ID or a `children` list,
/// styling with border radius, background color, padding, and elevation shadow.
///
/// ```dart
/// final component = buildA2uiCard(context, componentContext);
/// ```
Component buildA2uiCard(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final childIds = extractChildIds(props['children']);
  final elevation = asDouble(props['elevation'], 1);

  final List<Component> content;
  if (childId != null) {
    content = [componentContext.buildChild(childId)];
  } else if (childIds.isNotEmpty) {
    content = componentContext.buildChildren(childIds);
  } else {
    content = const [];
  }

  return div(
    classes: 'a2ui-card',
    styles: Styles(
      padding: const Spacing.all(Unit.pixels(16)),
      margin: const Spacing.symmetric(vertical: Unit.pixels(8)),
      radius: const BorderRadius.circular(Unit.pixels(8)),
      border: const Border.all(
        color: Color('#e5e7eb'),
        width: Unit.pixels(1),
      ),
      backgroundColor: Colors.white,
      shadow: BoxShadow(
        offsetX: Unit.zero,
        offsetY: Unit.pixels(elevation),
        blur: Unit.pixels(elevation * 2),
        color: const Color('rgba(0, 0, 0, 0.08)'),
      ),
    ),
    content,
  );
}
