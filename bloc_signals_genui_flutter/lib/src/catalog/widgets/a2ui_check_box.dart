import 'package:bloc_signals_genui_flutter/src/a2ui_component_context.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';

/// Renders an A2UI `CheckBox` component with two-way boolean data binding and
/// `CheckRule` validation error display.
///
/// ```dart
/// final widget = buildA2uiCheckBox(context, componentContext);
/// ```
Widget buildA2uiCheckBox(
  BuildContext context,
  A2uiComponentContext componentContext,
) {
  final props = componentContext.props;
  final label = asString(props['label']);
  final isChecked = asBool(props['value']);
  final checkErrors = componentContext.validationErrors;
  final errorText = !componentContext.isValid && checkErrors.isNotEmpty
      ? checkErrors.first
      : null;

  return CheckboxListTile(
    title: Text(label),
    subtitle: errorText != null
        ? Text(
            errorText,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        : null,
    value: isChecked,
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    onChanged: (nextValue) {
      componentContext.updateBoundValue('value', nextValue ?? false);
    },
  );
}
