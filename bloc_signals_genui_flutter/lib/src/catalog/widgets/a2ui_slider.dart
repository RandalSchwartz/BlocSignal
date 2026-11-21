import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
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
  final range = parseSliderRange(props);
  final min = range.min;
  final max = range.max;
  final currentValue = range.value;
  final divisions = range.divisions;

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
        divisions: divisions,
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
