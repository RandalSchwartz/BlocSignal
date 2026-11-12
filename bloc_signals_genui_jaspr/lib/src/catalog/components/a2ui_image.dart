import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

const Set<String> _allowedFits = <String>{
  'contain',
  'cover',
  'fill',
  'none',
  'scaleDown',
};

const Set<String> _allowedVariants = <String>{
  'icon',
  'avatar',
  'smallFeature',
  'mediumFeature',
  'largeFeature',
  'header',
};

bool _isAllowedHttpUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

/// Renders an A2UI `Image` component supporting `url`, `description`, `fit`
/// (`contain`, `cover`, `fill`, `none`, `scaleDown`), and `variant` sizing
/// (`icon`, `avatar`, `smallFeature`, `mediumFeature`, `largeFeature`,
/// `header`).
///
/// Validates that `url` uses an `http:` or `https:` scheme before rendering
/// `<img>`, falling back to a clean placeholder otherwise.
///
/// ```dart
/// final component = buildA2uiImage(context, componentContext);
/// ```
Component buildA2uiImage(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final url = asString(props['url']).trim();
  final description = unwrapBinding(props['description'])?.toString();
  final rawFit = asString(props['fit'], 'fill');
  final fit = _allowedFits.contains(rawFit) ? rawFit : 'fill';
  final rawVariant = asString(props['variant'], 'mediumFeature');
  final variant =
      _allowedVariants.contains(rawVariant) ? rawVariant : 'mediumFeature';

  final (Unit width, Unit height, Unit radius) = switch (variant) {
    'icon' => (const Unit.pixels(24), const Unit.pixels(24), Unit.zero),
    'avatar' => (
        const Unit.pixels(48),
        const Unit.pixels(48),
        const Unit.pixels(24),
      ),
    'smallFeature' => (
        const Unit.pixels(120),
        const Unit.pixels(80),
        const Unit.pixels(8),
      ),
    'largeFeature' => (
        const Unit.pixels(360),
        const Unit.pixels(240),
        const Unit.pixels(8),
      ),
    'header' => (
        const Unit.percent(100),
        const Unit.pixels(180),
        const Unit.pixels(8),
      ),
    _ => (
        const Unit.pixels(240),
        const Unit.pixels(160),
        const Unit.pixels(8),
      ),
  };

  if (!_isAllowedHttpUrl(url)) {
    return div(
      classes: 'a2ui-image a2ui-image-fallback a2ui-image-variant-$variant',
      attributes: {
        'role': 'img',
        if (description != null && description.isNotEmpty)
          'aria-label': description,
      },
      styles: Styles(
        width: width,
        height: height,
        radius: BorderRadius.circular(radius),
        backgroundColor: const Color('#f3f4f6'),
        display: Display.flex,
        alignItems: AlignItems.center,
        justifyContent: JustifyContent.center,
        color: const Color('#6b7280'),
      ),
      [Component.text(description ?? 'Image unavailable')],
    );
  }

  return img(
    src: url,
    alt: description ?? '',
    classes: 'a2ui-image a2ui-image-fit-$fit a2ui-image-variant-$variant',
    styles: Styles(
      width: width,
      height: height,
      radius: BorderRadius.circular(radius),
      display: Display.block,
    ),
  );
}
