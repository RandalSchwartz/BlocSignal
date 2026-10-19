import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `Slider` component with safe range clamping, two-way
/// numeric data binding, and `CheckRule` validation error display.
///
/// ```dart
/// final widget = buildA2uiSlider(context, componentContext);
/// ```
Widget buildA2uiSlider(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final label = unwrapBinding(props['label'])?.toString();
  final rawMin = asDouble(props['min']);
  final rawMax = asDouble(props['max'], 100);
  final min = rawMin <= rawMax ? rawMin : 0.0;
  final max = rawMax >= min ? (rawMax > min ? rawMax : min + 100.0) : 100.0;
  final currentValue = asDouble(props['value'], min).clamp(min, max);

  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null && label.isNotEmpty)
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        label: label,
        onChanged: (nextValue) {
          componentContext.updateBoundValue('value', nextValue);
        },
      ),
      if (errorText != null)
        Text(
          errorText,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
    ],
  );
}
