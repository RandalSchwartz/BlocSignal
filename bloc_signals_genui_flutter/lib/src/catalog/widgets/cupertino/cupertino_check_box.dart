import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/cupertino_tokens.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/cupertino.dart';

/// Renders an A2UI `CheckBox` component using [CupertinoCheckbox] with two-way
/// boolean data binding and `CheckRule` validation error display.
///
/// ```dart
/// final widget = buildCupertinoCheckBox(context, componentContext);
/// ```
Widget buildCupertinoCheckBox(
  BuildContext context,
  A2uiComponentContext componentContext, {
  CupertinoCatalogTokens? tokens,
}) {
  final props = componentContext.props;
  final label = asString(props['label']);
  final isChecked = asBool(props['value']);
  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  final activeColor = tokens?.primaryColor;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            componentContext.updateBoundValue('value', !isChecked);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoCheckbox(
                value: isChecked,
                activeColor: activeColor,
                onChanged: (nextValue) {
                  componentContext.updateBoundValue(
                    'value',
                    nextValue ?? false,
                  );
                },
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2),
            child: Text(
              errorText,
              style: const TextStyle(
                color: CupertinoColors.destructiveRed,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}
