import 'dart:async';

import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Modal` component using [showCupertinoModalPopup] and
/// [CupertinoPopupSurface] to display the `content` child when the `trigger`
/// child is tapped.
///
/// Supports both v0.9/v1.0 `trigger` and `content` properties and legacy
/// `entryPointChild` and `contentChild` aliases.
///
/// ```dart
/// final widget = buildCupertinoModal(context, componentContext);
/// ```
Widget buildCupertinoModal(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final triggerId = extractChildId(
    props['trigger'] ?? props['entryPointChild'],
  );
  final contentId = extractChildId(
    props['content'] ?? props['contentChild'],
  );

  if (triggerId == null || triggerId.isEmpty) {
    return const SizedBox.shrink();
  }

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: contentId == null || contentId.isEmpty
        ? null
        : () {
            unawaited(
              showCupertinoModalPopup<void>(
                context: context,
                builder: (modalContext) => CupertinoPopupSurface(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: componentContext.buildChild(contentId),
                    ),
                  ),
                ),
              ),
            );
          },
    child: componentContext.buildChild(triggerId),
  );
}
