import 'package:bloc_signals_genui_jaspr/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_jaspr/src/catalog/safe_prop_parser.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders an A2UI `Slider` component with safe range clamping, `steps` to
/// HTML `step` interval mapping, two-way numeric data binding, and `CheckRule`
/// validation error display.
///
/// ```dart
/// final component = buildA2uiSlider(context, componentContext);
/// ```
Component buildA2uiSlider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final labelText = unwrapBinding(props['label'])?.toString();
  final rawMin = asDouble(props['min']);
  final rawMax = asDouble(props['max'], 100);
  final min = rawMin <= rawMax ? rawMin : 0.0;
  final max = rawMax >= min ? (rawMax > min ? rawMax : min + 100.0) : 100.0;
  final currentValue = asDouble(props['value'], min).clamp(min, max);

  final rawSteps = props['steps'] ?? props['divisions'];
  final parsedSteps = rawSteps != null ? asInt(rawSteps) : 0;
  final step = parsedSteps >= 1 ? (max - min) / parsedSteps : null;

  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  return div(
    classes: 'a2ui-slider-container',
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
        type: InputType.range,
        value: currentValue.toString(),
        classes: 'a2ui-slider',
        attributes: {
          'min': min.toString(),
          'max': max.toString(),
          if (step != null) 'step': step.toString(),
        },
        onInput: (rawNext) {
          final parsed = double.tryParse(rawNext);
          if (parsed != null) {
            componentContext.updateBoundValue('value', parsed.clamp(min, max));
          }
        },
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
