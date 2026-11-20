import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/a2ui_image_url_policy.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Renders an A2UI `Image` component supporting `url`, `description`, `fit`
/// (`contain`, `cover`, `fill`, `none`, `scaleDown`), and `variant` sizing
/// (`icon`, `avatar`, `smallFeature`, `mediumFeature`, `largeFeature`,
/// `header`) with URL policy validation via [imagePolicy], bounded decode
/// `cacheWidth`/`cacheHeight`, and a resilient offline `errorBuilder` fallback.
///
/// ```dart
/// final widget = buildA2uiImage(context, componentContext);
/// ```
Widget buildA2uiImage(
  BuildContext context,
  A2uiComponentContext componentContext, {
  A2uiImageUrlPolicy imagePolicy = const A2uiImageUrlPolicy(),
}) {
  final props = componentContext.props;
  final url = asString(props['url']);
  final description = unwrapBinding(props['description'])?.toString();
  final fitStr = asString(props['fit'], 'fill');
  final variant = asString(props['variant'], 'mediumFeature');

  final boxFit = switch (fitStr) {
    'contain' => BoxFit.contain,
    'cover' => BoxFit.cover,
    'none' => BoxFit.none,
    'scaleDown' => BoxFit.scaleDown,
    _ => BoxFit.fill,
  };

  final (double width, double height, BorderRadius borderRadius) =
      switch (variant) {
    'icon' => (24.0, 24.0, BorderRadius.zero),
    'avatar' => (48.0, 48.0, BorderRadius.circular(24)),
    'smallFeature' => (120.0, 80.0, BorderRadius.circular(8)),
    'largeFeature' => (360.0, 240.0, BorderRadius.circular(8)),
    'header' => (double.infinity, 180.0, BorderRadius.circular(8)),
    _ => (240.0, 160.0, BorderRadius.circular(8)),
  };

  Widget fallbackPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        semanticLabel: description,
      ),
    );
  }

  if (!imagePolicy.isAllowed(url)) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: fallbackPlaceholder(),
    );
  }

  final dpr = MediaQuery.devicePixelRatioOf(context);
  int? boundedCacheExtent(double logical) {
    if (!logical.isFinite || logical <= 0 || !dpr.isFinite || dpr <= 0) {
      return null;
    }
    return (logical * dpr).round().clamp(1, 1 << 30);
  }

  return ClipRRect(
    borderRadius: borderRadius,
    child: Image.network(
      url.trim(),
      width: width,
      height: height,
      cacheWidth: boundedCacheExtent(width),
      cacheHeight: boundedCacheExtent(height),
      fit: boxFit,
      semanticLabel: description,
      errorBuilder: (context, error, stackTrace) => fallbackPlaceholder(),
    ),
  );
}
