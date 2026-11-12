import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `DateTimeInput` component supporting ISO 8601 date and time
/// selection (`enableDate` and `enableTime`), `min`/`max` bounds, two-way data
/// binding, and `CheckRule` validation error display.
///
/// ```dart
/// final component = buildA2uiDateTimeInput(context, componentContext);
/// ```
Component buildA2uiDateTimeInput(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final labelText = unwrapBinding(props['label'])?.toString();
  final rawValue = asString(props['value']);
  final enableDate = asBool(props['enableDate'], defaultValue: true);
  final enableTime = asBool(props['enableTime']);
  final minVal = asString(props['min']);
  final maxVal = asString(props['max']);

  final InputType inputType;
  if (enableDate && enableTime) {
    inputType = InputType.dateTimeLocal;
  } else if (!enableDate && enableTime) {
    inputType = InputType.time;
  } else {
    inputType = InputType.date;
  }

  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  return div(
    classes: 'a2ui-datetime-container',
    styles: const Styles(
      display: Display.flex,
      flexDirection: FlexDirection.column,
      margin: Spacing.symmetric(vertical: Unit.pixels(6)),
    ),
    [
      if (labelText != null && labelText.isNotEmpty)
        label(
          classes: 'a2ui-label',
          styles: const Styles(
            fontSize: Unit.pixels(14),
            fontWeight: FontWeight.w600,
            margin: Spacing.only(bottom: Unit.pixels(4)),
            color: Color('#374151'),
          ),
          [Component.text(labelText)],
        ),
      input<String>(
        type: inputType,
        value: rawValue,
        classes: 'a2ui-datetime-input',
        attributes: {
          if (minVal.isNotEmpty) 'min': minVal,
          if (maxVal.isNotEmpty) 'max': maxVal,
        },
        onInput: (nextValue) {
          componentContext.updateBoundValue('value', nextValue);
        },
        styles: Styles(
          padding: const Spacing.symmetric(
            vertical: Unit.pixels(8),
            horizontal: Unit.pixels(12),
          ),
          border: Border.all(
            color: errorText != null
                ? const Color('#dc2626')
                : const Color('#d1d5db'),
            width: const Unit.pixels(1),
          ),
          radius: const BorderRadius.circular(Unit.pixels(4)),
          fontSize: const Unit.pixels(14),
        ),
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
