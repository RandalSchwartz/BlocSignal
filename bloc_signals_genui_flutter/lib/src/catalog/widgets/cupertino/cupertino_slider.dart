import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
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
  final range = parseSliderRange(props);
  final min = range.min;
  final max = range.max;
  final currentValue = range.value;
  final divisions = range.divisions;

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
          divisions: divisions,
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
