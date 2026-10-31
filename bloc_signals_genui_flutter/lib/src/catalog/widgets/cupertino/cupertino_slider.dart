import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `Slider` component using [CupertinoSlider] with safe range
/// clamping, two-way numeric data binding, and `CheckRule` validation error
/// display.
///
/// ```dart
/// final widget = buildCupertinoSlider(context, componentContext);
/// ```
Widget buildCupertinoSlider(
  BuildContext context,
  A2uiComponentContext componentContext, {
  CupertinoCatalogTokens? tokens,
}) {
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

  final activeColor = tokens?.primaryColor;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null && label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
          ),
        ),
      SizedBox(
        width: double.infinity,
        child: CupertinoSlider(
          value: currentValue,
          min: min,
          max: max,
          activeColor: activeColor,
          onChanged: (nextValue) {
            componentContext.updateBoundValue('value', nextValue);
          },
        ),
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            errorText,
            style: const TextStyle(
              color: CupertinoColors.destructiveRed,
              fontSize: 12,
            ),
          ),
        ),
    ],
  );
}
