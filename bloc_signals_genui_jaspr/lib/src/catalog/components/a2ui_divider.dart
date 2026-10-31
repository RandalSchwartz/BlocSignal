import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Divider` component in the DOM.
///
/// Supports `axis` (`horizontal` or `vertical`), `height`, `width`, and
/// `thickness`.
///
/// ```dart
/// final component = buildA2uiDivider(context, componentContext);
/// ```
Component buildA2uiDivider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final axis = asString(props['axis'], 'horizontal');
  final thickness = asDouble(props['thickness'], 1);

  if (axis == 'vertical') {
    final dividerHeight = asDouble(props['height'] ?? props['width'], 16);
    return div(
      classes: 'a2ui-divider a2ui-divider-vertical',
      styles: Styles(
        display: Display.inlineBlock,
        width: Unit.pixels(thickness),
        height: Unit.pixels(dividerHeight),
        backgroundColor: const Color('#e5e7eb'),
      ),
      const [],
    );
  }

  final dividerSpacing = asDouble(props['height'], 16);
  return hr(
    classes: 'a2ui-divider a2ui-divider-horizontal',
    styles: Styles(
      border: Border.only(
        top: BorderSide(
          width: Unit.pixels(thickness),
          color: const Color('#e5e7eb'),
        ),
      ),
      margin: Spacing.symmetric(vertical: Unit.pixels(dividerSpacing / 2)),
    ),
  );
}
