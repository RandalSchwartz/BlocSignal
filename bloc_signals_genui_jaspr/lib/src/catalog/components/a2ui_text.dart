import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Text` component with typography hierarchy.
///
/// Supports `variant` (`h1`, `h2`, `h3`, `h4`, `h5`, `title`, `caption`, and
/// `body`) as well as the `style` property fallback.
///
/// ```dart
/// final component = buildA2uiText(context, componentContext);
/// ```
Component buildA2uiText(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final textContent = asString(props['text']);
  final variant = asString(props['variant'] ?? props['style'], 'body');

  return switch (variant) {
    'h1' => h1(
        classes: 'a2ui-text a2ui-text-h1',
        [Component.text(textContent)],
      ),
    'h2' => h2(
        classes: 'a2ui-text a2ui-text-h2',
        [Component.text(textContent)],
      ),
    'h3' => h3(
        classes: 'a2ui-text a2ui-text-h3',
        [Component.text(textContent)],
      ),
    'h4' => h4(
        classes: 'a2ui-text a2ui-text-h4',
        [Component.text(textContent)],
      ),
    'h5' || 'title' => h5(
        classes: 'a2ui-text a2ui-text-h5',
        [Component.text(textContent)],
      ),
    'caption' => p(
        classes: 'a2ui-text a2ui-text-caption',
        styles: const Styles(
          fontSize: Unit.pixels(12),
          color: Color('#6b7280'),
          margin: Spacing.zero,
        ),
        [Component.text(textContent)],
      ),
    _ => p(
        classes: 'a2ui-text a2ui-text-body',
        styles: const Styles(margin: Spacing.zero),
        [Component.text(textContent)],
      ),
  };
}
