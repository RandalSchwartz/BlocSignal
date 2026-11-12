import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `CheckBox` component with two-way boolean data binding and
/// `CheckRule` validation error display.
///
/// ```dart
/// final component = buildA2uiCheckBox(context, componentContext);
/// ```
Component buildA2uiCheckBox(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final labelText = asString(props['label']);
  final isChecked = asBool(props['value']);
  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  return div(
    classes: 'a2ui-checkbox-container',
    styles: const Styles(
      display: Display.flex,
      flexDirection: FlexDirection.column,
      margin: Spacing.symmetric(vertical: Unit.pixels(4)),
    ),
    [
      label(
        classes: 'a2ui-checkbox-label',
        styles: const Styles(
          display: Display.inlineFlex,
          alignItems: AlignItems.center,
          cursor: Cursor.pointer,
        ),
        [
          input<bool>(
            type: InputType.checkbox,
            checked: isChecked,
            classes: 'a2ui-checkbox',
            onChange: (nextValue) {
              componentContext.updateBoundValue('value', nextValue);
            },
            styles: const Styles(
              margin: Spacing.only(right: Unit.pixels(8)),
            ),
          ),
          if (labelText.isNotEmpty) span([Component.text(labelText)]),
        ],
      ),
      if (errorText != null)
        span(
          classes: 'a2ui-error-text',
          styles: const Styles(
            color: Color('#dc2626'),
            fontSize: Unit.pixels(12),
            margin: Spacing.only(top: Unit.pixels(4)),
          ),
          [Component.text(errorText)],
        ),
    ],
  );
}
