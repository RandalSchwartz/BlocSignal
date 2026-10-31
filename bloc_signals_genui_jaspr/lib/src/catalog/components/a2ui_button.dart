import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Button` component in the DOM.
///
/// Automatically disables the button (`disabled: true`) when
/// [A2uiComponentContext.isValid] is `false` (for example due to a failing
/// `CheckRule`) or when `props['enabled']` evaluates to `false`.
///
/// ```dart
/// final component = buildA2uiButton(context, componentContext);
/// ```
Component buildA2uiButton(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final childId = extractChildId(props['child']);
  final variant = asString(props['variant'], 'primary');
  final rawAction = props['action'];
  final modelAction = componentContext.component.properties['action'];

  final isEnabled =
      componentContext.isValid && asBool(props['enabled'], defaultValue: true);

  final childComponent = childId != null
      ? componentContext.buildChild(childId)
      : const Component.text('Action');

  void handlePressed() {
    var actionName = 'submit';
    var actionContext = const <String, dynamic>{};

    final sourceAction =
        rawAction is Map || rawAction is String ? rawAction : modelAction;

    if (sourceAction is Map) {
      final eventMap =
          sourceAction['event'] is Map ? sourceAction['event'] as Map : null;
      if (eventMap != null) {
        actionName = eventMap['name']?.toString() ?? 'submit';
        if (eventMap['context'] is Map) {
          actionContext = Map<String, dynamic>.from(eventMap['context'] as Map);
        }
      } else if (sourceAction['name'] != null) {
        actionName = sourceAction['name'].toString();
      }

      if (actionContext.isEmpty && sourceAction['context'] is Map) {
        actionContext =
            Map<String, dynamic>.from(sourceAction['context'] as Map);
      }
    } else if (sourceAction is String) {
      actionName = sourceAction;
    }

    componentContext.dispatchAction(actionName, context: actionContext);
  }

  final styles = variant == 'borderless'
      ? Styles(
          backgroundColor: Colors.transparent,
          border: const Border.all(style: BorderStyle.none),
          color: const Color('#2563eb'),
          cursor: isEnabled ? Cursor.pointer : Cursor.defaultCursor,
          padding: const Spacing.symmetric(
            vertical: Unit.pixels(8),
            horizontal: Unit.pixels(16),
          ),
          radius: const BorderRadius.circular(Unit.pixels(4)),
        )
      : Styles(
          backgroundColor:
              isEnabled ? const Color('#2563eb') : const Color('#9ca3af'),
          border: const Border.all(style: BorderStyle.none),
          color: Colors.white,
          cursor: isEnabled ? Cursor.pointer : Cursor.defaultCursor,
          padding: const Spacing.symmetric(
            vertical: Unit.pixels(8),
            horizontal: Unit.pixels(16),
          ),
          radius: const BorderRadius.circular(Unit.pixels(4)),
        );

  return button(
    classes: 'a2ui-button a2ui-button-$variant',
    disabled: !isEnabled,
    onClick: isEnabled ? handlePressed : null,
    styles: styles,
    [childComponent],
  );
}
