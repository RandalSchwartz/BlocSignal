import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Image` component supporting `url`, `description`, `fit`
/// (`contain`, `cover`, `fill`, `none`, `scaleDown`), and `variant` sizing
/// (`icon`, `avatar`, `smallFeature`, `mediumFeature`, `largeFeature`,
/// `header`) with iOS-styled placeholder and error fallbacks.
///
/// ```dart
/// final widget = buildCupertinoImage(context, componentContext);
/// ```
Widget buildCupertinoImage(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
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
    'avatar' => (48.0, 48.0, const BorderRadius.all(Radius.circular(24))),
    'smallFeature' => (120.0, 80.0, const BorderRadius.all(Radius.circular(8))),
    'largeFeature' => (
        360.0,
        240.0,
        const BorderRadius.all(Radius.circular(8))
      ),
    'header' => (
        double.infinity,
        180.0,
        const BorderRadius.all(Radius.circular(8)),
      ),
    _ => (240.0, 160.0, const BorderRadius.all(Radius.circular(8))),
  };

  Widget fallbackPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGrey5,
        context,
      ),
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.photo,
        semanticLabel: description,
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.systemGrey,
          context,
        ),
      ),
    );
  }

  if (url.isEmpty) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: fallbackPlaceholder(),
    );
  }

  return ClipRRect(
    borderRadius: borderRadius,
    child: Image.network(
      url,
      width: width,
      height: height,
      fit: boxFit,
      semanticLabel: description,
      errorBuilder: (errorContext, error, stackTrace) => fallbackPlaceholder(),
    ),
  );
}
